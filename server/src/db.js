import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);

// better-sqlite3 tersedia di Linux cloud dengan prebuilt binary
// Tidak perlu compile - langsung gunakan
const Database = require('better-sqlite3');

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_DIR = path.resolve(__dirname, process.env.DATA_DIR || '../data');

// Pastikan folder data ada
fs.mkdirSync(path.join(DATA_DIR, 'uploads'), { recursive: true });
fs.mkdirSync(path.join(DATA_DIR, 'quarantine'), { recursive: true });

const dbPath = path.join(DATA_DIR, 'internal-cloud.db');
const db = new Database(dbPath);

// WAL mode untuk performa lebih baik
db.exec(`PRAGMA journal_mode = WAL;`);
db.exec(`PRAGMA foreign_keys = ON;`);

// ═══════════════════════════════════════════════════════════════
// Migrasi tabel
// ═══════════════════════════════════════════════════════════════

export function initDB() {
  db.exec(`
    CREATE TABLE IF NOT EXISTS users (
      id          TEXT PRIMARY KEY,
      username    TEXT UNIQUE NOT NULL,
      password    TEXT NOT NULL,
      display_name TEXT,
      google_refresh_token TEXT,
      google_drive_email TEXT,
      created_at  INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER) * 1000)
    );

    CREATE TABLE IF NOT EXISTS messages (
      id          TEXT PRIMARY KEY,
      user_id     TEXT NOT NULL REFERENCES users(id),
      body        TEXT,
      ts          INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER) * 1000),
      chat_date   TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS files (
      id              TEXT PRIMARY KEY,
      message_id      TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
      user_id         TEXT NOT NULL REFERENCES users(id),
      original_name   TEXT NOT NULL,
      stored_name     TEXT NOT NULL,
      mime            TEXT NOT NULL,
      category        TEXT NOT NULL DEFAULT 'other',
      size_bytes      INTEGER NOT NULL DEFAULT 0,
      quarantined     INTEGER NOT NULL DEFAULT 0,
      drive_file_id   TEXT,
      ts              INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER) * 1000)
    );

    CREATE INDEX IF NOT EXISTS idx_messages_ts ON messages(ts DESC);
    CREATE INDEX IF NOT EXISTS idx_messages_chat_date ON messages(chat_date);
    CREATE INDEX IF NOT EXISTS idx_messages_user ON messages(user_id);
    CREATE INDEX IF NOT EXISTS idx_files_category ON files(category);
    CREATE INDEX IF NOT EXISTS idx_files_ts ON files(ts DESC);
    CREATE INDEX IF NOT EXISTS idx_files_user ON files(user_id);
    CREATE INDEX IF NOT EXISTS idx_files_mime ON files(mime);
  `);

  // Migrasi untuk DB lama
  try {
    const userCols = db.prepare(`PRAGMA table_info(users)`).all().map(c => c.name);
    if (!userCols.includes('google_refresh_token')) {
      db.exec(`ALTER TABLE users ADD COLUMN google_refresh_token TEXT`);
    }
    if (!userCols.includes('google_drive_email')) {
      db.exec(`ALTER TABLE users ADD COLUMN google_drive_email TEXT`);
    }
    const fileCols = db.prepare(`PRAGMA table_info(files)`).all().map(c => c.name);
    if (!fileCols.includes('drive_file_id')) {
      db.exec(`ALTER TABLE files ADD COLUMN drive_file_id TEXT`);
    }
  } catch (e) {
    console.log('[DB] Migration:', e.message);
  }

  // FTS5 search index
  try {
    db.exec(`
      CREATE VIRTUAL TABLE IF NOT EXISTS search_index USING fts5(
        file_id,
        content,
        tokenize='porter unicode61'
      );
    `);
  } catch (e) {
    console.log('[DB] FTS5:', e.message);
  }

  console.log('[DB] Database initialized at', dbPath);
  return db;
}

export default db;
