import { Router } from 'express';
import multer from 'multer';
import db from '../db.js';
import { authMiddleware } from '../middleware/auth.js';
import {
  genId, getCategory, validateMagicBytes, getExtension,
  getMimeFromExt, formatDate, formatTimestamp,
} from '../utils/fileUtils.js';
import { saveObject, deleteObject, getStorageMode } from '../services/storage.js';
import { uploadBufferToDrive, isUserDriveConnected, isDriveConfigured } from '../services/googleDrive.js';
import { pushToUserDevices } from '../services/websocket.js';

const router = Router();
router.use(authMiddleware);

const MAX_FILE_MB = parseInt(process.env.MAX_FILE_SIZE_MB) || 50;
const MAX_BYTES = MAX_FILE_MB * 1024 * 1024;
const ALLOWED_EXTS = (process.env.ALLOWED_EXTENSIONS || 'pdf,docx,doc,xlsx,xls,pptx,txt,csv,png,jpg,jpeg,gif,webp,zip,rar,7z')
  .split(',').map(s => s.trim().toLowerCase());

// Storage ke memory dulu supaya bisa validasi magic bytes sebelum simpan
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: MAX_BYTES },
});

// ═══════════════════════════════════════════════════════════════
// POST /api/upload - upload file + pesan teks
// multipart/form-data: file, message
// ═══════════════════════════════════════════════════════════════
router.post('/', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Tidak ada file yang diupload' });
    }

    const originalName = req.file.originalname;
    const ext = getExtension(originalName);
    const message = (req.body.message || '').trim();
    const saveToDrive = req.body.save_to_drive === 'true' || req.body.save_to_drive === '1';

    // 1. Validasi ekstensi whitelist
    if (!ALLOWED_EXTS.includes(ext)) {
      return res.status(400).json({
        error: `Ekstensi .${ext} tidak diizinkan`,
        allowed: ALLOWED_EXTS,
      });
    }

    // 2. Tentukan MIME dari ekstensi
    const mime = getMimeFromExt(ext) || req.file.mimetype;

    // 3. Validasi magic bytes (cek isi file, bukan cuma ekstensi)
    if (mime !== 'application/octet-stream') {
      if (!validateMagicBytes(req.file.buffer, mime)) {
        return res.status(400).json({
          error: 'Isi file tidak sesuai dengan ekstensinya. File mungkin rusak atau disamarkan.',
        });
      }
    }

    // 4. Buat message + file di DB (transaksi manual)
    const messageId = genId();
    const fileId = genId();
    const ts = Date.now();
    const chatDate = formatDate(ts);
    const storedName = `${fileId}.${ext}`;

    // 5. Tulis file ke storage DULU (kalau gagal, langsung berhenti)
    try {
      await saveObject({ storedName, buffer: req.file.buffer });
    } catch (e) {
      return res.status(500).json({ error: 'Gagal menyimpan file ke storage: ' + e.message });
    }

    // 6. Simpan record DB (kalau gagal, hapus file yang sudah ditulis)
    db.exec('BEGIN');
    try {
      // Simpan message
      db.prepare(
        'INSERT INTO messages (id, user_id, body, ts, chat_date) VALUES (?, ?, ?, ?, ?)'
      ).run(messageId, req.userId, message || null, ts, chatDate);

      // Simpan file row
      db.prepare(`
        INSERT INTO files (id, message_id, user_id, original_name, stored_name, mime, category, size_bytes, quarantined, ts)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?)
      `).run(fileId, messageId, req.userId, originalName, `${fileId}.${ext}`, mime, getCategory(mime), req.file.size, ts);

      db.exec('COMMIT');
    } catch (e) {
      db.exec('ROLLBACK');
      // Bersihkan objek storage yang sudah ditulis karena DB gagal
      try {
        await deleteObject(storedName);
      } catch (_) {}
      throw e;
    }

    // Upload ke Google Drive (opsional: jika diminta & user terhubung)
    let driveFileId = null;
    let driveWebLink = null;
    if (saveToDrive) {
      if (!isDriveConfigured()) {
        return res.status(400).json({ error: 'Google Drive belum dikonfigurasi di server (GOOGLE_CLIENT_ID belum diisi).' });
      }
      if (!isUserDriveConnected(req.userId)) {
        return res.status(400).json({ error: 'Belum terhubung ke Google Drive. Hubungkan dulu di menu Akun.' });
      }
      try {
        const r = await uploadBufferToDrive(req.userId, {
          filename: originalName,
          mime,
          buffer: req.file.buffer,
        });
        if (r) {
          driveFileId = r.driveFileId;
          driveWebLink = r.webViewLink;
          db.prepare('UPDATE files SET drive_file_id = ? WHERE id = ?').run(driveFileId, fileId);
        }
      } catch (drvErr) {
        console.error('[UPLOAD→DRIVE]', drvErr.message);
        // Jangan gagalkan upload lokal kalau Drive gagal; laporkan saja
        // (file tetap tersimpan lokal, tapi tidak di Drive)
        driveFileId = null;
      }
    }

    res.status(201).json({
      message: 'File berhasil diupload',
      data: {
        file: {
          id: fileId,
          original_name: originalName,
          mime,
          category: getCategory(mime),
          size_bytes: req.file.size,
          ts,
          ts_formatted: formatTimestamp(ts),
          drive_file_id: driveFileId,
          drive_web_link: driveWebLink,
        },
        message: {
          id: messageId,
          body: message || null,
          ts,
          date: chatDate,
        },
      },
    });

    // Push notifikasi ke mobile device via WebSocket
    // Kirim info file baru agar mobile bisa auto-download
    try {
      pushToUserDevices(req.userId, {
        type: 'file_uploaded',
        file: {
          id: fileId,
          original_name: originalName,
          mime,
          category: getCategory(mime),
          size_bytes: req.file.size,
          message: message || null,
          ts,
        },
      }, req.headers['x-device-id'] || null);
    } catch (_) {}
  } catch (e) {
    console.error('[UPLOAD]', e);
    return res.status(500).json({ error: 'Gagal mengupload file: ' + e.message });
  }
});

export default router;
