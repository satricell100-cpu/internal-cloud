import { Router } from 'express';
import db from '../db.js';
import { authMiddleware } from '../middleware/auth.js';
import { genId, formatDate, formatTimestamp } from '../utils/fileUtils.js';

const router = Router();
router.use(authMiddleware);

// ═══════════════════════════════════════════════════════════════
// GET /api/messages - daftar pesan (kronologis, descending)
// Query: ?limit=50&offset=0
// ═══════════════════════════════════════════════════════════════
router.get('/', (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 50, 200);
  const offset = parseInt(req.query.offset) || 0;

  const messages = db.prepare(`
    SELECT m.*,
           (SELECT COUNT(*) FROM files f WHERE f.message_id = m.id) as file_count
    FROM messages m
    WHERE m.user_id = ?
    ORDER BY m.ts DESC
    LIMIT ? OFFSET ?
  `).all(req.userId, limit, offset);

  const filesByMessage = new Map();

  for (const m of messages) {
    const files = db.prepare(`
      SELECT id, message_id, original_name, mime, category, size_bytes, ts
      FROM files
      WHERE user_id = ? AND message_id = ?
      ORDER BY ts ASC
    `).all(req.userId, m.id);

    filesByMessage.set(
      m.id,
      files.map(f => ({
        id: f.id,
        message_id: f.message_id,
        original_name: f.original_name,
        mime: f.mime,
        category: f.category,
        size_bytes: f.size_bytes,
        ts: f.ts,
        download_url: `/api/files/${f.id}/download`,
        preview_url: f.category === 'image' ? `/api/files/${f.id}/raw` : null,
      }))
    );
  }

  res.json({
    messages: messages.map(m => ({
      ...m,
      files: filesByMessage.get(m.id) || [],
      ts_formatted: formatTimestamp(m.ts),
      date: formatDate(m.ts),
    })),
  });
});

// ═══════════════════════════════════════════════════════════════
// POST /api/messages - kirim pesan teks saja
// Body: { body: "laporan mingguan" }
// ═══════════════════════════════════════════════════════════════
router.post('/', (req, res) => {
  const { body } = req.body;

  if (!body || !body.trim()) {
    return res.status(400).json({ error: 'Pesan tidak boleh kosong' });
  }

  const id = genId();
  const ts = Date.now();
  db.prepare(
    'INSERT INTO messages (id, user_id, body, ts, chat_date) VALUES (?, ?, ?, ?, ?)'
  ).run(id, req.userId, body.trim(), ts, formatDate(ts));

  res.status(201).json({
    message: 'Pesan terkirim',
    data: {
      id,
      body: body.trim(),
      ts,
      ts_formatted: formatTimestamp(ts),
      date: formatDate(ts),
      file_count: 0,
    },
  });
});

// ═══════════════════════════════════════════════════════════════
// GET /api/messages/:id - detail pesan + file terikat
// ═══════════════════════════════════════════════════════════════
router.get('/:id', (req, res) => {
  const msg = db.prepare(
    'SELECT * FROM messages WHERE id = ? AND user_id = ?'
  ).get(req.params.id, req.userId);

  if (!msg) {
    return res.status(404).json({ error: 'Pesan tidak ditemukan' });
  }

  const files = db.prepare(
    'SELECT id, original_name, mime, category, size_bytes, ts FROM files WHERE message_id = ?'
  ).all(msg.id);

  res.json({
    message: msg,
    files,
  });
});

export default router;
