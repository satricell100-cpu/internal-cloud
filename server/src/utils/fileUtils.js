import { v4 as uuidv4 } from 'uuid';

// ═══════════════════════════════════════════════════════════════
// Kategori file berdasarkan MIME type
// ═══════════════════════════════════════════════════════════════

const MIME_CATEGORIES = {
  // Dokumen
  'application/pdf': 'document',
  'application/msword': 'document',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'document',
  'application/vnd.ms-excel': 'document',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'document',
  'application/vnd.ms-powerpoint': 'document',
  'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'document',
  'text/plain': 'document',
  'text/csv': 'document',
  'text/markdown': 'document',

  // Gambar
  'image/png': 'image',
  'image/jpeg': 'image',
  'image/gif': 'image',
  'image/webp': 'image',
  'image/bmp': 'image',
  'image/svg+xml': 'image',

  // Arsip
  'application/zip': 'archive',
  'application/x-rar-compressed': 'archive',
  'application/vnd.rar': 'archive',
  'application/x-7z-compressed': 'archive',
  'application/gzip': 'archive',
  'application/x-tar': 'archive',
};

// ═══════════════════════════════════════════════════════════════
// Magic bytes untuk validasi file (mencegah spoofing ekstensi)
// ═══════════════════════════════════════════════════════════════

const MAGIC_BYTES = [
  { mime: 'application/pdf',                   magic: [0x25, 0x50, 0x44, 0x46], offset: 0 },        // %PDF
  { mime: 'image/png',                         magic: [0x89, 0x50, 0x4E, 0x47], offset: 0 },        // .PNG
  { mime: 'image/jpeg',                        magic: [0xFF, 0xD8, 0xFF],         offset: 0 },        // ÿØÿ
  { mime: 'image/gif',                         magic: [0x47, 0x49, 0x46, 0x38], offset: 0 },        // GIF8
  { mime: 'application/zip',                   magic: [0x50, 0x4B, 0x03, 0x04], offset: 0 },        // PK..
  { mime: 'application/x-rar-compressed',      magic: [0x52, 0x61, 0x72, 0x21], offset: 0 },        // Rar!
  { mime: 'application/vnd.rar',               magic: [0x52, 0x61, 0x72, 0x21], offset: 0 },        // Rar!
  { mime: 'application/x-7z-compressed',       magic: [0x37, 0x7A, 0xBC, 0xAF], offset: 0 },        // 7z..
  { mime: 'application/gzip',                  magic: [0x1F, 0x8B],              offset: 0 },
];

// ═══════════════════════════════════════════════════════════════
// Fungsi utilitas
// ═══════════════════════════════════════════════════════════════

export function genId() {
  return uuidv4();
}

export function getCategory(mimeType) {
  return MIME_CATEGORIES[mimeType] || 'other';
}

export function validateMagicBytes(buffer, mimeType) {
  // Cari magic bytes yang sesuai dengan MIME type
  const expected = MAGIC_BYTES.filter(m => m.mime === mimeType);
  if (expected.length === 0) return true; // Tidak ada aturan magic bytes untuk MIME ini

  for (const rule of expected) {
    let match = true;
    for (let i = 0; i < rule.magic.length; i++) {
      if (buffer[rule.offset + i] !== rule.magic[i]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

export function getExtension(filename) {
  const idx = filename.lastIndexOf('.');
  return idx >= 0 ? filename.substring(idx + 1).toLowerCase() : '';
}

export function getMimeFromExt(ext) {
  const map = {
    pdf: 'application/pdf',
    doc: 'application/msword',
    docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    xls: 'application/vnd.ms-excel',
    xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    pptx: 'application/vnd.ms-powerpoint',
    txt: 'text/plain',
    csv: 'text/csv',
    png: 'image/png',
    jpg: 'image/jpeg',
    jpeg: 'image/jpeg',
    gif: 'image/gif',
    webp: 'image/webp',
    bmp: 'image/bmp',
    svg: 'image/svg+xml',
    zip: 'application/zip',
    rar: 'application/x-rar-compressed',
    '7z': 'application/x-7z-compressed',
    gz: 'application/gzip',
    tar: 'application/x-tar',
  };
  return map[ext] || 'application/octet-stream';
}

export function formatDate(timestamp) {
  const d = new Date(timestamp);
  return d.toISOString().split('T')[0]; // YYYY-MM-DD
}

export function formatTimestamp(timestamp) {
  return new Date(timestamp).toISOString();
}

export function truncate(str, maxLen = 200) {
  if (!str || str.length <= maxLen) return str;
  return str.substring(0, maxLen) + '...';
}
