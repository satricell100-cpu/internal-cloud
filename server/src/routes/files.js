import { Router } from 'express';
import fs from 'fs';
import db from '../db.js';
import { authMiddleware } from '../middleware/auth.js';
import { getCategory, formatDate, formatTimestamp } from '../utils/fileUtils.js';
import { resolveObjectPath } from '../services/storage.js';

const router = Router();
router.use(authMiddleware);

// ═══════════════════════════════════════════════════════════════
// GET /api/files - daftar file
// Query: ?category=image|document|archive&limit=100&offset=0
// ═══════════════════════════════════════════════════════════════
router.get('/', (req, res) => {
  const { category } = req.query;
  const limit = Math.min(parseInt(req.query.limit) || 100, 200);
  const offset = parseInt(req.query.offset) || 0;

  let query = 'SELECT * FROM files WHERE user_id = ?';
  const params = [req.userId];

  if (category) {
    query += ' AND category = ?';
    params.push(category);
  }

  query += ' ORDER BY ts DESC LIMIT ? OFFSET ?';
  params.push(limit, offset);

  const files = db.prepare(query).all(...params);

  res.json({
    files: files.map(f => ({
      ...f,
      ts_formatted: formatTimestamp(f.ts),
      date: formatDate(f.ts),
      download_url: `/api/files/${f.id}/download`,
    })),
  });
});

// ═══════════════════════════════════════════════════════════════
// GET /api/files/categories - ringkasan jumlah file per kategori
// ═══════════════════════════════════════════════════════════════
router.get('/categories', (req, res) => {
  const rows = db.prepare(`
    SELECT category, COUNT(*) as count
    FROM files
    WHERE user_id = ?
    GROUP BY category
  `).all(req.userId);

  res.json({ categories: rows });
});

// ═══════════════════════════════════════════════════════════════
// GET /api/files/:id/download - download file (stream)
// ═══════════════════════════════════════════════════════════════
router.get('/:id/download', async (req, res) => {
  const file = db.prepare(
    'SELECT * FROM files WHERE id = ? AND user_id = ?'
  ).get(req.params.id, req.userId);

  if (!file) {
    return res.status(404).json({ error: 'File tidak ditemukan' });
  }
  if (file.quarantined) {
    return res.status(423).json({ error: 'File dalam karantina (terindikasi virus)' });
  }

  const filePath = await resolveObjectPath(file.stored_name);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File fisik tidak ditemukan di server' });
  }

  res.download(filePath, file.original_name);
});

// ═══════════════════════════════════════════════════════════════
// GET /api/files/:id - metadata + preview info
// ═══════════════════════════════════════════════════════════════
router.get('/:id', (req, res) => {
  const file = db.prepare(
    'SELECT * FROM files WHERE id = ? AND user_id = ?'
  ).get(req.params.id, req.userId);

  if (!file) {
    return res.status(404).json({ error: 'File tidak ditemukan' });
  }

  if (file.quarantined) {
    return res.status(423).json({ error: 'File dalam karantina (terindikasi virus)' });
  }

  res.json({
    file: {
      ...file,
      ts_formatted: formatTimestamp(file.ts),
      date: formatDate(file.ts),
      download_url: `/api/files/${file.id}/download`,
      // Preview URL hanya untuk gambar (tampil langsung)
      preview_url: file.category === 'image'
        ? `/api/files/${file.id}/raw`
        : null,
    },
  });
});

// ═══════════════════════════════════════════════════════════════
// GET /api/files/:id/raw - tampilkan file mentah (untuk preview gambar)
// ═══════════════════════════════════════════════════════════════
router.get('/:id/raw', async (req, res) => {
  const file = db.prepare(
    'SELECT * FROM files WHERE id = ? AND user_id = ?'
  ).get(req.params.id, req.userId);

  if (!file) {
    return res.status(404).json({ error: 'File tidak ditemukan' });
  }
  if (file.quarantined) {
    return res.status(423).json({ error: 'File dalam karantina' });
  }

  const filePath = await resolveObjectPath(file.stored_name);
  if (!fs.existsSync(filePath)) {
    return res.status(404).json({ error: 'File fisik tidak ditemukan' });
  }

  res.setHeader('Content-Type', file.mime);
  res.setHeader('Content-Length', file.size_bytes);
  res.sendFile(filePath);
});

export default router;
