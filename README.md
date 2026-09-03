# Internal Cloud

Aplikasi cloud pribadi berbasis chat (konsep seperti WhatsApp) untuk mengelola file.
Upload file sambil menandai dengan pesan teks → file otomatis terorganisir per kategori & bisa dicari.

## Arsitektur

- `server/` — Backend Node.js + Express + SQLite (node:sqlite bawaan, tanpa install DB server)
- `mobile/` — Aplikasi Flutter (Android/iOS)
- Storage file default masih lokal.
- Nanti bisa dipindah ke S3-compatible storage dengan env `STORAGE_DRIVER=s3` + `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_PREFIX`.

## Menjalankan Server

Double-klik `server/mulai.bat`, atau manual:

```
cd server
npm install        # sekali saja
npm start          # atau: node src/index.js
```

Server jalan di: http://localhost:3000
Health check:     http://localhost:3000/api/health

## Menjalankan Aplikasi di HP

### 1. Atur alamat server di `mobile/lib/services/app_config.dart`

```dart
class AppConfig {
  // Emulator Android:
  static const String baseUrl = 'http://10.0.2.2:3000';

  // HP fisik / LAN (pakai IP komputer kamu):
  // static const String baseUrl = 'http://192.168.1.10:3000';

  // Server online:
  // static const String baseUrl = 'https://cloud.domainmu.com';
}
```

> Saat HP fisik dan komputer berada di WiFi yang sama, pakai IP LAN komputer.
> Cek IP komputer: `ipconfig` di cmd (cari IPv4 Address).

### 2. Build APK

```
cd mobile
flutter build apk --release
```

Hasil APK: `mobile/build/app/outputs/flutter-apk/app-release.apk`
Kirim/copy APK ke HP (via WhatsApp, USB, Google Drive, dll) lalu install.

### 3. Jalankan langsung dari komputer (untuk test cepat)

```
cd mobile
flutter run
```

## Fitur

- **Chat-based upload**: upload file + ketik pesan (seperti kirim di WhatsApp)
- **Organisasi otomatis**: file tersusun otomatis per kategori (Gambar / Dokumen / Arsip) + per tanggal
- **Pencarian ala WhatsApp**: ketik teks → pesan & file yang cocok muncul
- **Preview & download**: lihat gambar langsung, unduh file ke HP
- **Keamanan**: tolak file berbahaya (.exe), tolak file yang disamarkan (cek isi file)

## API Ringkasan

| Method | Endpoint | Fungsi |
|:-------|:---------|:-------|
| POST | `/api/auth/register` | Daftar akun |
| POST | `/api/auth/login` | Login → JWT |
| GET | `/api/messages` | Daftar pesan |
| POST | `/api/messages` | Kirim pesan teks |
| POST | `/api/upload` | Upload file + pesan |
| GET | `/api/files` | Daftar file per kategori |
| GET | `/api/files/:id/download` | Download file |
| GET | `/api/search?q=...` | Pencarian |
