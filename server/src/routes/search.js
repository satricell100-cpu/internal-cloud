import { Router } from 'express';
import db from '../db.js';
import { authMiddleware } from '../middleware/auth.js';
import { formatDate, formatTimestamp } from '../utils/fileUtils.js';

const router = Router();
router.use(authMiddleware);

// ═══════════════════════════════════════════════════════════════
// GET /api/search?q=... - pencarian FTS5 ala WhatsApp
// Mencari di: nama file, pesan teks, konten teks dokumen
// ═══════════════════════════════════════════════════════════════
router.get('/', (req, res) => {
  const q = (req.query.q || '').trim();
  const limit = Math.min(parseInt(req.query.limit) || 30, 100);

  if (!q) {
    return res.status(400).json({ error: 'Query pencarian (q) wajib diisi' });
  }

  const results = [];

  // 1. Cari di FTS5 index (file content + nama)
  try {
    // Escape untuk FTS5 - gabung dengan OR agar fleksibel
    const terms = q.split(/\s+/).filter(Boolean);
    const ftsQuery = terms.map(t => `"${t.replace(/"/g, '""')}"*`).join(' AND ');

    if (terms.length > 0) {
      const ftsRows = db.prepare(`
        SELECT f.id as file_id, f.message_id, f.original_name, f.category, f.mime, f.size_bytes, f.ts,
               si.content as matched_content
        FROM search_index si
        JOIN files f ON f.id = si.file_id
        WHERE search_index MATCH ?
          AND f.user_id = ?
        ORDER BY f.ts DESC
        LIMIT ?
      `).all(ftsQuery, req.userId, limit);

      for (const row of ftsRows) {
        results.push({
          type: 'file',
          file_id: row.file_id,
          message_id: row.message_id,
          name: row.original_name,
          category: row.category,
          mime: row.mime,
          size_bytes: row.size_bytes,
          ts: row.ts,
          ts_formatted: formatTimestamp(row.ts),
          date: formatDate(row.ts),
        });
      }
    }
  } catch (e) {
    // FTS5 bisa error jika query sintaks tidak valid - fallback ke LIKE
    console.log('[SEARCH] FTS error, fallback:', e.message);
  }

  // 2. Cari di messages (pesan teks) - LIKE fallback yang selalu jalan
  const like = `%${q}%`;
  const msgRows = db.prepare(`
    SELECT id, body, ts
    FROM messages
    WHERE user_id = ? AND body LIKE ?
    ORDER BY ts DESC
    LIMIT ?
  `).all(req.userId, like, limit);

  for (const row of msgRows) {
    results.push({
      type: 'message',
      message_id: row.id,
      body: row.body,
      ts: row.ts,
      ts_formatted: formatTimestamp(row.ts),
      date: formatDate(row.ts),
    });
  }

  // 3. Cari di nama file (selalu jalan, tidak butuh FTS)
  const fileRows = db.prepare(`
    SELECT id, message_id, original_name, category, mime, size_bytes, ts
    FROM files
    WHERE user_id = ? AND original_name LIKE ?
    ORDER BY ts DESC
    LIMIT ?
  `).all(req.userId, like, limit);

  for (const row of fileRows) {
    results.push({
      type: 'file',
      file_id: row.id,
      message_id: row.message_id,
      name: row.original_name,
      category: row.category,
      mime: row.mime,
      size_bytes: row.size_bytes,
      ts: row.ts,
      ts_formatted: formatTimestamp(row.ts),
      date: formatDate(row.ts),
    });
  }

  // Hapus duplikat (file yang muncul di FTS dan LIKE)
  const seen = new Set();
  const unique = results.filter(r => {
    const key = r.type + ':' + (r.file_id || r.message_id);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });

  // Urutkan: paling baru di atas
  unique.sort((a, b) => b.ts - a.ts);

  res.json({
    query: q,
    count: unique.length,
    results: unique.slice(0, limit),
  });
});

export default router;
