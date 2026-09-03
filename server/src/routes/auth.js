import { Router } from 'express';
import bcrypt from 'bcryptjs';
import db from '../db.js';
import { genId } from '../utils/fileUtils.js';
import { generateToken, authMiddleware } from '../middleware/auth.js';

const router = Router();

// ═══════════════════════════════════════════════════════════════
// Get current user profile
// ═══════════════════════════════════════════════════════════════
router.get('/me', authMiddleware, (req, res) => {
  const user = db.prepare('SELECT id, username, display_name, created_at FROM users WHERE id = ?').get(req.userId);
  if (!user) {
    return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  }
  res.json({ user });
});

// ═══════════════════════════════════════════════════════════════
// Update profile
// ═══════════════════════════════════════════════════════════════
router.put('/profile', authMiddleware, (req, res) => {
  const { display_name, current_password, new_password } = req.body;
  const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.userId);
  if (!user) {
    return res.status(404).json({ error: 'Pengguna tidak ditemukan' });
  }

  let hash = user.password;
  if (new_password) {
    if (!current_password) {
      return res.status(400).json({ error: 'Password saat ini harus diisi untuk mengubah password' });
    }
    if (!bcrypt.compareSync(current_password, user.password)) {
      return res.status(400).json({ error: 'Password saat ini salah' });
    }
    if (new_password.length < 4) {
      return res.status(400).json({ error: 'Password baru minimal 4 karakter' });
    }
    hash = bcrypt.hashSync(new_password, 10);
  }

  const updatedName = display_name !== undefined ? display_name.trim() : user.display_name;
  db.prepare('UPDATE users SET display_name = ?, password = ? WHERE id = ?').run(
    updatedName,
    hash,
    req.userId
  );

  res.json({
    message: 'Profil berhasil diperbarui',
    user: { id: user.id, username: user.username, display_name: updatedName },
  });
});

// ═══════════════════════════════════════════════════════════════
// Register user
// ═══════════════════════════════════════════════════════════════
router.post('/register', (req, res) => {
  const { username, password, display_name } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username dan password wajib diisi' });
  }
  if (username.length < 3) {
    return res.status(400).json({ error: 'Username minimal 3 karakter' });
  }
  if (password.length < 4) {
    return res.status(400).json({ error: 'Password minimal 4 karakter' });
  }

  // Cek username sudah dipakai
  const existing = db.prepare('SELECT id FROM users WHERE username = ?').get(username);
  if (existing) {
    return res.status(409).json({ error: 'Username sudah terdaftar' });
  }

  const id = genId();
  const hash = bcrypt.hashSync(password, 10);
  db.prepare(
    'INSERT INTO users (id, username, password, display_name) VALUES (?, ?, ?, ?)'
  ).run(id, username, hash, display_name || username);

  const token = generateToken(id);
  res.status(201).json({
    message: 'Registrasi berhasil',
    token,
    user: { id, username, display_name: display_name || username },
  });
});

// ═══════════════════════════════════════════════════════════════
// Login
// ═══════════════════════════════════════════════════════════════
router.post('/login', (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username dan password wajib diisi' });
  }

  const user = db.prepare('SELECT * FROM users WHERE username = ?').get(username);
  if (!user || !bcrypt.compareSync(password, user.password)) {
    return res.status(401).json({ error: 'Username atau password salah' });
  }

  const token = generateToken(user.id);
  res.json({
    message: 'Login berhasil',
    token,
    user: { id: user.id, username: user.username, display_name: user.display_name },
  });
});

export default router;
