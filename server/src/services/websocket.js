// ═══════════════════════════════════════════════════════════════
// WebSocket Sync Manager
// Mengelola koneksi antar device: mobile ↔ web ↔ server
// ═══════════════════════════════════════════════════════════════
import { WebSocketServer } from 'ws';
import jwt from 'jsonwebtoken';

// Baca JWT_SECRET secara LAZY (di dalam fungsi), bukan di module scope.
// Karena ESM imports dievaluasi sebelum dotenv.config() berjalan, baca di
// module scope akan mendapat nilai kosong. auth.js sudah baca lazy.
function getJwtSecret() {
  return process.env.JWT_SECRET || 'internal-cloud-secret-dev';
}

// Map: userId → Map<deviceId, WebSocket>
const devices = new Map();

export function setupWebSocket(server) {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', (ws, req) => {
    console.log('[WS] New connection');

    ws.isAlive = true;
    ws.userId = null;
    ws.deviceId = null;
    ws.deviceType = null; // 'mobile' | 'web'

    // Heartbeat
    ws.on('pong', () => { ws.isAlive = true; });

    ws.on('message', (data) => {
      try {
        const msg = JSON.parse(data.toString());
        handleWSMessage(ws, msg);
      } catch (e) {
        ws.send(JSON.stringify({ type: 'error', message: 'Invalid message format' }));
      }
    });

    ws.on('close', () => {
      if (ws.userId && ws.deviceId) {
        const userDevices = devices.get(ws.userId);
        if (userDevices) {
          userDevices.delete(ws.deviceId);
          if (userDevices.size === 0) devices.delete(ws.userId);
        }
        console.log(`[WS] Device disconnected: ${ws.deviceId} (user: ${ws.userId})`);
      }
    });
  });

  // Heartbeat interval: tutup koneksi mati tiap 30 detik
  const heartbeat = setInterval(() => {
    wss.clients.forEach((ws) => {
      if (!ws.isAlive) {
        if (ws.userId && ws.deviceId) {
          const userDevices = devices.get(ws.userId);
          if (userDevices) userDevices.delete(ws.deviceId);
        }
        return ws.terminate();
      }
      ws.isAlive = false;
      ws.ping();
    });
  }, 30000);

  wss.on('close', () => clearInterval(heartbeat));

  console.log('[WS] WebSocket server ready at /ws');
  return wss;
}

// ═══════════════════════════════════════════════════════════════
// Handle pesan dari client
// ═══════════════════════════════════════════════════════════════
function handleWSMessage(ws, msg) {
  switch (msg.type) {
    case 'register': {
      // Client register: { type: 'register', token: 'jwt', deviceId: 'xxx', deviceType: 'mobile'|'web' }
      const { token, deviceId, deviceType } = msg;
      if (!token || !deviceId) {
        return ws.send(JSON.stringify({ type: 'error', message: 'token & deviceId required' }));
      }
      try {
        const decoded = jwt.verify(token, getJwtSecret());
        ws.userId = decoded.id || decoded.userId;
        ws.deviceId = deviceId;
        ws.deviceType = deviceType || 'unknown';

        // Simpan ke map
        if (!devices.has(ws.userId)) devices.set(ws.userId, new Map());
        devices.get(ws.userId).set(deviceId, ws);

        const deviceCount = devices.get(ws.userId).size;
        console.log(`[WS] Registered: ${ws.deviceType} ${ws.deviceId} (user: ${ws.userId}, total: ${deviceCount})`);

        ws.send(JSON.stringify({
          type: 'registered',
          userId: ws.userId,
          deviceId: ws.deviceId,
          deviceCount,
        }));
      } catch (e) {
        ws.send(JSON.stringify({ type: 'error', message: 'Invalid token' }));
        ws.close();
      }
      break;
    }

    case 'file_uploaded': {
      // Server → Client: file baru diupload (dipanggil dari upload route)
      // Pesan ini dikirim dari pushToUserDevices()
      break;
    }

    case 'request_file': {
      // Mobile minta info file tertentu untuk download
      // { type: 'request_file', fileId: 'xxx' }
      // Nanti bisa expand dengan mengirim file info
      ws.send(JSON.stringify({ type: 'file_info', fileId: msg.fileId }));
      break;
    }

    case 'ping': {
      ws.send(JSON.stringify({ type: 'pong', time: Date.now() }));
      break;
    }

    default:
      ws.send(JSON.stringify({ type: 'error', message: `Unknown type: ${msg.type}` }));
  }
}

// ═══════════════════════════════════════════════════════════════
// Push event ke semua device milik user (kecuali sender)
// ═══════════════════════════════════════════════════════════════
export function pushToUserDevices(userId, message, excludeDeviceId = null) {
  const userDevices = devices.get(userId);
  if (!userDevices) return 0;

  let pushed = 0;
  for (const [deviceId, ws] of userDevices) {
    if (deviceId === excludeDeviceId) continue;
    if (ws.readyState === 1) { // OPEN
      ws.send(JSON.stringify(message));
      pushed++;
    }
  }
  return pushed;
}

// ═══════════════════════════════════════════════════════════════
// Cek apakah user punya device mobile yang terhubung
// ═══════════════════════════════════════════════════════════════
export function hasMobileDevice(userId) {
  const userDevices = devices.get(userId);
  if (!userDevices) return false;
  for (const [, ws] of userDevices) {
    if (ws.deviceType === 'mobile' && ws.readyState === 1) return true;
  }
  return false;
}

export function getDeviceCount(userId) {
  return devices.get(userId)?.size || 0;
}
