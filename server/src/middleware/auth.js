import jwt from 'jsonwebtoken';

// Baca JWT_SECRET secara LAZY. Karena ESM imports dievaluasi sebelum
// dotenv.config() berjalan (di index.js), membaca di module scope akan
// mendapat nilai kosong. Baca di dalam fungsi saat dipanggil.
const JWT_EXPIRES = process.env.JWT_EXPIRES_IN || '7d';
function getJwtSecret() {
  return process.env.JWT_SECRET || 'internal-cloud-secret-dev';
}

export function generateToken(userId) {
  return jwt.sign({ userId }, getJwtSecret(), { expiresIn: JWT_EXPIRES });
}

export function authMiddleware(req, res, next) {
  let token = null;
  const header = req.headers.authorization;
  
  if (header && header.startsWith('Bearer ')) {
    token = header.split(' ')[1];
  } else if (req.query && req.query.token) {
    token = req.query.token;
  } else if (req.headers['x-auth-token']) {
    token = req.headers['x-auth-token'];
  }

  if (!token) {
    return res.status(401).json({ error: 'Tidak ada token, silakan login' });
  }

  try {
    const payload = jwt.verify(token, getJwtSecret());
    req.userId = payload.userId;
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Token tidak valid atau kadaluarsa' });
  }
}
