import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { createServer } from 'http';

import os from 'os';

dotenv.config();

import { initDB } from './db.js';
import authRoutes from './routes/auth.js';
import messageRoutes from './routes/messages.js';
import fileRoutes from './routes/files.js';
import uploadRoutes from './routes/upload.js';
import searchRoutes from './routes/search.js';
import driveRoutes from './routes/drive.js';
import { setupWebSocket, pushToUserDevices } from './services/websocket.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const publicDir = path.join(__dirname, '../public');

// Inisialisasi database
initDB();

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Middleware
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Static frontend web app
app.use(express.static(publicDir));

// Helper: ambil IP LAN lokal
function getLocalIpAddresses() {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name] || []) {
      if (iface.family === 'IPv4' && !iface.internal) {
        addresses.push({ interface: name, address: iface.address });
      }
    }
  }
  return addresses;
}

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'internal-cloud',
    version: '1.0.0',
    time: new Date().toISOString(),
  });
});

// Network & Deployment info endpoint (WLAN vs Cloud mode)
app.get('/api/network/info', (req, res) => {
  const ips = getLocalIpAddresses();
  const primaryIp = ips.find(i => i.address.startsWith('192.168.') || i.address.startsWith('10.'))?.address || ips[0]?.address || '127.0.0.1';
  const isCloud = process.env.NODE_ENV === 'production' || !!process.env.RENDER || !!process.env.RAILWAY_ENVIRONMENT;

  res.json({
    mode: isCloud ? 'cloud' : 'hybrid_wlan',
    port: PORT,
    localIps: ips,
    primaryLocalIp: primaryIp,
    localUrl: `http://${primaryIp}:${PORT}`,
    cloudUrl: process.env.PUBLIC_URL || null,
    storageDriver: process.env.STORAGE_DRIVER || 'local',
  });
});

// Mount routes
app.use('/api/auth', authRoutes);
app.use('/api/messages', messageRoutes);
app.use('/api/files', fileRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/search', searchRoutes);
app.use('/api/drive', driveRoutes);

// SPA fallback for Web App
app.get('*', (req, res, next) => {
  if (req.path.startsWith('/api') || req.path.startsWith('/ws')) {
    return next();
  }
  res.sendFile(path.join(publicDir, 'index.html'));
});

// 404 handler for API
app.use((req, res) => {
  res.status(404).json({ error: 'Endpoint tidak ditemukan' });
});

// Error handler (harus 4 argumen)
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error('[ERROR]', err.message);

  // Multer error untuk file terlalu besar
  if (err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({ error: `File terlalu besar. Maksimal ${process.env.MAX_FILE_SIZE_MB || 50}MB` });
  }

  res.status(err.status || 500).json({
    error: err.message || 'Terjadi kesalahan pada server',
  });
});

// Create HTTP server + attach WebSocket
const server = createServer(app);
setupWebSocket(server);

// Export pushToUserDevices so upload route can use it
export { pushToUserDevices };

// Start server
server.listen(PORT, HOST, () => {
  console.log('');
  console.log('══════════════════════════════════════');
  console.log('  Internal Cloud Server');
  console.log('  Chat-based file storage backend');
  console.log('');
  console.log(`  Local:      http://localhost:${PORT}`);
  console.log(`  Health:     http://localhost:${PORT}/api/health`);
  console.log('══════════════════════════════════════');
  console.log('');
});
