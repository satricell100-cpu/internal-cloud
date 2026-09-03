# Panduan Deploy Internal Cloud (Web & Mobile Sync)

Aplikasi **Internal Cloud** mendukung dua mode pengoperasian:
1. **Mode WLAN Lokal (WiFi Sama)**: Transfer tercepat direct antar PC & HP tanpa kuota internet.
2. **Mode Cloud Hosting (Internet / Beda Jaringan)**: File disimpan di cloud server dan disinkronkan ke HP saat HP online di mana saja.

---

## Opsi 1: Deploy ke Render (Gratis & Mudah)

1. Buat akun di [Render.com](https://render.com).
2. Buat repository Git baru (GitHub / GitLab) dan push folder project ini.
3. Di Dashboard Render, klik **New +** → **Web Service**.
4. Hubungkan repository Anda.
5. Isi konfigurasi:
   - **Root Directory**: `server`
   - **Environment**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node src/index.js`
   - **Disk (Persistent Storage)**: Tambahkan disk di `/app/data` (1GB gratis).
6. Render akan memberikan URL domain (contoh: `https://internal-cloud.onrender.com`).
7. Buka URL tersebut di browser laptop Anda, dan ganti `baseUrl` di aplikasi Flutter HP ke URL tersebut!

---

## Opsi 2: Deploy ke Railway / VPS (Docker)

1. Jalankan perintah Docker di server Anda:
   ```bash
   docker build -t internal-cloud ./server
   docker run -d -p 3000:3000 -v internal_data:/app/data internal-cloud
   ```
2. Aplikasi Web dan API siap diakses publik di port 3000!

---

## Cara Menghubungkan HP ke Web:

1. **Jika di WiFi yang sama (WLAN)**:
   - Di laptop/PC, buka browser ke `http://<IP-Laptop>:3000` (misal: `http://192.168.1.21:3000`).
   - Di aplikasi HP Flutter, set `AppConfig.baseUrl = 'http://192.168.1.21:3000'`.
   - File yang dikirim dari browser laptop akan langsung masuk ke HP secara direct.

2. **Jika beda jaringan (Cloud Hosting)**:
   - Buka alamat URL hosting (misal: `https://cloud.domainmu.com`) di browser laptop.
   - Di aplikasi HP Flutter, set `AppConfig.baseUrl = 'https://cloud.domainmu.com'`.
   - Kirim file dari laptop di kantor/rumah → file tersimpan di server dan seketika masuk ke HP Anda di mana pun berada.
