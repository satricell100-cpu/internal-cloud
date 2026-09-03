import { Router } from 'express';
import multer from 'multer';
import { google } from 'googleapis';
import db from '../db.js';
import { authMiddleware } from '../middleware/auth.js';
import { uploadBufferToDrive, getOAuthClient, isDriveConfigured } from '../services/googleDrive.js';

const router = Router();
router.use(authMiddleware);

// Multer untuk upload ke Google Drive (memory storage)
const driveUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: (parseInt(process.env.MAX_FILE_SIZE_MB) || 50) * 1024 * 1024 },
});

function getScopes() {
  return [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/userinfo.email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ];
}

// ═══════════════════════════════════════════════════════════════
// GET /api/drive/auth-url
// → URL untuk memulai OAuth Google (buka di browser)
// ═══════════════════════════════════════════════════════════════
router.get('/auth-url', (req, res) => {
  try {
    if (!isDriveConfigured()) {
      return res.status(400).json({ error: 'Google Drive belum dikonfigurasi di server. Isi GOOGLE_CLIENT_ID/SECRET di .env' });
    }
    const oauth = getOAuthClient();
    const authUrl = oauth.generateAuthUrl({
      access_type: 'offline',
      prompt: 'consent',
      scope: getScopes(),
      state: req.userId, // kirim userId sebagai state supaya callback tahu siapa
    });
    res.json({ authUrl });
  } catch (e) {
    res.status(500).json({ error: e.message });
  }
});

// ═══════════════════════════════════════════════════════════════
// GET /api/drive/callback?code=...&state=...
// → Tukar kode auth jadi token, simpan refresh_token ke user
// ═══════════════════════════════════════════════════════════════
router.get('/callback', async (req, res) => {
  try {
    const { code, state } = req.query;
    if (!code) {
      return res.status(400).send('Kode otorisasi tidak ada. Tutup jendela ini dan coba lagi.');
    }
    if (!state) {
      return res.status(400).send('state tidak ada (userId hilang).');
    }

    const userId = state;
    const oauth = getOAuthClient();
    const { tokens } = await oauth.getToken(code);
    oauth.setCredentials(tokens);

    if (!tokens.refresh_token) {
      return res.status(400).send('Tidak mendapat refresh_token. Pastikan prompt=consent & access_type=offline.');
    }

    // Ambil email user Google
    let email = '';
    try {
      const people = google.people({ version: 'v1', auth: oauth });
      const me = await people.people.get({
        resourceName: 'people/me',
        personFields: 'emailAddresses',
      });
      email = me.data?.emailAddresses?.[0]?.value || '';
    } catch (_) {
      // email opsional
    }

    // Simpan refresh token + email ke DB
    db.prepare(
      'UPDATE users SET google_refresh_token = ?, google_drive_email = ? WHERE id = ?'
    ).run(tokens.refresh_token, email, userId);

    res.type('html').send(`
      <html><body style="font-family:sans-serif;text-align:center;padding-top:60px;">
        <h2 style="color:#128C7E;">✓ Terhubung ke Google Drive</h2>
        <p>${email ? `Akun: <b>${email}</b>` : 'Akun Google'}</p>
        <p>Berhasil terhubung. Silakan kembali ke aplikasi.</p>
        <script>setTimeout(()=>window.close(), 1500);</script>
      </body></html>
    `);
  } catch (e) {
    console.error('[DRIVE callback]', e.message);
    res.status(500).send('Gagal terhubung ke Google Drive: ' + e.message);
  }
});

// ═══════════════════════════════════════════════════════════════
// GET /api/drive/status
// → Cek apakah user sudah terhubung ke Google Drive
// ═══════════════════════════════════════════════════════════════
router.get('/status', (req, res) => {
  const user = db.prepare('SELECT google_refresh_token, google_drive_email FROM users WHERE id = ?').get(req.userId);
  if (user && user.google_refresh_token) {
    return res.json({
      connected: true,
      email: user.google_drive_email || null,
    });
  }
  res.json({ connected: false, email: null });
});

// ═══════════════════════════════════════════════════════════════
// POST /api/drive/disconnect
// → Hapus koneksi Google Drive
// ═══════════════════════════════════════════════════════════════
router.post('/disconnect', (req, res) => {
  db.prepare(
    'UPDATE users SET google_refresh_token = NULL, google_drive_email = NULL WHERE id = ?'
  ).run(req.userId);
  res.json({ connected: false, message: 'Google Drive diputus' });
});

// ═══════════════════════════════════════════════════════════════
// POST /api/drive/upload
// multipart/form-data: file
// → Upload file ke Google Drive (folder root 'Internal Cloud')
// ═══════════════════════════════════════════════════════════════
router.post('/upload', driveUpload.single('file'), async (req, res) => {
  if (!isDriveConfigured()) {
    return res.status(400).json({ error: 'Google Drive belum dikonfigurasi di server.' });
  }
  if (!req.file) {
    return res.status(400).json({ error: 'Tidak ada file untuk diupload ke Google Drive' });
  }
  try {
    const r = await uploadBufferToDrive(req.userId, {
      filename: req.file.originalname,
      mime: req.file.mimetype,
      buffer: req.file.buffer,
    });
    if (!r) {
      return res.status(401).json({ error: 'Belum terhubung ke Google Drive. Hubungkan dulu di menu Akun.' });
    }
    return res.json({
      success: true,
      driveFileId: r.driveFileId,
      webViewLink: r.webViewLink,
    });
  } catch (e) {
    console.error('[DRIVE upload]', e.message);
    res.status(500).json({ error: 'Gagal upload ke Google Drive: ' + e.message });
  }
});

export default router;
