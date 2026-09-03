# Internal Cloud — Aplikasi Cloud Pribadi Berbasis Chat

## 1. Visi Produk

Aplikasi cloud pribadi yang bekerja seperti **chat WhatsApp** untuk mengelola file. Pengguna mengupload file (dokumen, gambar, arsip/rar) sambil menandainya dengan **pesan teks** (misal: "laporan mingguan"). Aplikasi **otomatis mengorganisir** file berdasarkan jenis & isinya, dan pengguna bisa **mencari** file persis seperti mencari pesan di WhatsApp — ketik teks, lalu file yang cocok muncul.

### Kelebihan utama
- **Rapih otomatis**: file tersusun otomatis per kategori (dokumen / gambar / arsip) dan per tanggal.
- **Cari ala WhatsApp**: ketik apa saja, dapat file yang relevan.
- **Internal + online**: bisa dipakai offline di HP, atau online (host di server sendiri / langganan VPS).
- **Sederhana**: pengguna tidak perlu berpikir soal folder — cukup "chat" dan file diurus sendiri.

---

## 2. Keputusan Arsitektur (sudah disepakati)

| Komponen | Pilihan | Alasan |
|:---------|:--------|:-------|
| Frontend (HP) | **Flutter** | Cross-platform (Android/iOS), kamu sudah berpengalaman Flutter |
| Backend | **Node.js + Express** | Ringan, ekosistem besar, bagus untuk upload/stream |
| Database | **SQLite** | File lokal, self-host tanpa install DB server, cocok single-user/family |
| File storage | **Disk lokal server** (folder data) | Simpel, bisa di-upload ke VPS/self-host |
| API | REST (JSON) | Standar, mudah diintegrasi Flutter |
| Auth | **JWT + PIN/biometric** | Sederhana untuk internal |

### Mode operasi (dual-mode)
1. **Internal (offline)**: aplikasi + data jalan penuh di HP. Untuk personal use.
2. **Online (sync ke server)**: backend di server sendiri / VPS langganan. HP upload → server simpan → bisa diakses perangkat lain.

Alur database: SQLite di dua tempat boleh, tapi desain utamanya: **backend server sebagai sumber kebenaran (source of truth)**. Mode internal = local-only server instance di HP, atau local cache yang sinkron ke server saat online.

---

## 3. Fitur (dalam bahasa produk)

### MVP (Wajib rilis pertama)
1. **Chat-based upload**
   - Kolom input seperti WhatsApp (teks + tombol attach/lampiran).
   - Saat attach, bisa pilih file (dokumen / gambar / rar) dari galeri / file manager.
   - Kirim = upload file + pesan teks jadi satu "gelembung chat".
2. **Organisasi otomatis**
   - File otomatis dikelompokkan per jenis: Dokumen, Gambar, Arsip (rar/zip).
   - Tersusun berdasarkan tanggal terbaru.
3. **Pencarian ala WhatsApp**
   - Kolom search di atas; ketik teks → muncul hasil chat + file yang cocok.
   - Pencarian mencakup nama file, teks pesan, dan konten teks dokumen (pdf/docx/txt).
4. **Menu "File tersimpan" (3 tab)**
   - Tab per kategori: Gambar / Dokumen / Arsip.
   - Di dalam tiap tab, file tampil grid/list tersusun tanggal.
5. **Preview & download**
   - Klik file → preview (gambar langsung, dokumen pdf/preview text, arsip = info isi).
   - Download/export ke penyimpanan HP.

### Fase 2 (setelah MVP jalan)
6. **Multi-perangkat & sync**: cloud online, akses dari HP lain / PC.
7. **Akun & sharing**: beberapa user, share file via link.
8. **Auto-tag dari isi**: OCR untuk gambar, ekstrak teks dokumen agar pencarian lebih kaya.
9. **Favorit / pin**: tandai file penting.
10. **Backup otomatis** ke cloud eksternal (Google Drive / S3 / VPS).

---

## 4. Keamanan (PENTING — file rar/malware)

Karena aplikasi menerima upload file (termasuk arsip/rar), desain ini wajib agar aplikasi tidak jadi gerbang malware:

1. **Whitelist ekstensi**: hanya terima ekstensi yang diizinkan (pdf, docx, xlsx, txt, png, jpg, gif, zip, rar). Tolak `.exe`, `.bat`, `.scr`, `.js`, `.sh`, dsb ke executable.
2. **Scan antivirus (mode online)**: di server, file diupload di-scan oleh clamav (free) sebelum disimpan final. Virus/infected → di-quarantine, tidak tampil di chat.
3. **Eksekusi NOL di server**: file arsip TIDAK pernah di-unzip/eksekusi/scanned-maliciously otomatis oleh server. Server hanya menyimpan + melayani download. Konteks file dibatasi.
4. **Quarantine folder**: file mencurigakan berdiri sendiri, diberi flag, tidak bisa di-preview/download normal.
5. **MIME check**: validasi signature file (magic bytes), bukan cuma ekstensi. PDF harus mulai `%PDF`, dll.

---

## 5. Data Model (SQLite)

### Tabel `messages`
```
id          TEXT (PK)          -- uuid
chat_id     TEXT               -- grup per tanggal/topik (chat-style)
user_id     TEXT               -- owner
body        TEXT               -- pesan teks (bisa kosong kalau hanya file)
ts          INTEGER            -- unix millis, untuk urutan/per tanggal
```

### Tabel `files`
```
id          TEXT (PK)          -- uuid
message_id  TEXT (FK)          -- file terikat ke satu chat-message
original_name TEXT             -- nama asli file
stored_name TEXT               -- nama file di disk (uuid + ext)
mime        TEXT               -- tipe MIME
category    TEXT               -- 'document' | 'image' | 'archive' | 'other'
size_bytes  INTEGER
url         TEXT               -- path/auth url untuk download
quarantined INTEGER  (0/1)     -- flag hasil scan
ts          INTEGER            -- tanggal upload
```

### Tabel `search_index` (FTS5 — pencarian cepat ala WA)
```
-- SQLite Full-Text Search
search_index (
  file_id  TEXT,
  content  TEXT   -- gabungan: nama file + pesan + ekstrak teks dokumen
)
```
SQLite punya modul **FTS5** bawaan yang pas untuk "search ala WhatsApp" — cocok & tanpa server tambahan.

### Model chat grouping
Mirip WA: file + pesan membentuk **percakapan**. Sederhananya MVP: satu "chat" per user (feed kronologis). Row `chat_id` disiapkan agar nanti bisa di-group (mis. per bulan / per topik).

---

## 6. API Backend (Express + SQLite)

### Base path: `/api`

| Method | Endpoint | Fungsi |
|:------|:---------|:-------|
| POST | `/auth/login` | Login (PIN/password) → JWT |
| POST | `/auth/refresh` | Refresh token |
| GET | `/messages` | Daftar chat/messages (pagination, tersusun tanggal) |
| POST | `/messages` | Kirim pesan teks saja |
| POST | `/upload` (multipart) | Upload file + pesan teks (satu request) |
| GET | `/files` | Daftar file (sudah dikelompok per kategori) |
| GET | `/files/:id` | Info / preview metadata file |
| GET | `/files/:id/download` | Download (stream) |
| GET | `/search?q=...` | Pencarian FTS5 → hasil messages + files |
| GET | `/files/category/:cat` | File per kategori (document/image/archive) |

### Upload flow
1. Client kirim `multipart/form-data`: `file` + `message` (teks).
2. Server validasi: ekstensi whitelist → magic bytes (MIME) → ukuran max.
3. Simpan file ke disk (`data/uploads/<uuid>.<ext>`), tulis row ke `files` + `messages`.
4. (online) Scan clamav → bila infected set `quarantined=1`.
5. Ekstrak teks (pdf/docx/txt) → isi ke `search_index`.
6. Balas JSON: metadata file + message.

### Struktur folder server
```
internal-cloud/
  server/
    src/
      index.js        -- entry, express app
      routes/         -- auth, messages, files, upload, search
      db.js           -- sqlite init + migrasi
      search.js       -- FTS5 setup & query
      validate.js     -- ekstensi whitelist + magic bytes
      antivirus.js    -- clamav scan (mode online)
    data/
      uploads/
      quarantine/
      internal-cloud.db   -- sqlite file
    package.json
  mobile/               -- Flutter app (bagian 7)
  plan.md
```

---

## 7. Mobile App (Flutter)

### Stack Flutter
- `http` / `dio` — REST client, upload multipart
- `provider` / `riverpod` — state management
- `sqflite` — local cache di HP (mode offline internal)
- `file_picker` / `image_picker` — pilih file/gambar/galeri
- `path_provider` — simpan/download ke penyimpanan HP
- `open_filex` — buka preview file

### Layar (screen)
1. **ChatScreen (utama)** — feed kronologis ala WA. Input box + attach.
   - Bubbles: file (ikon + nama + thumbnail) & pesan teks.
2. **SearchScreen** — kolom search, hasil dari `/api/search`. Muncul file + pesan yang cocok.
3. **FilesScreen** — bottom tab / segmented: "Gambar | Dokumen | Arsip".
   - Grid foto kiri, dokumen list, arsip list. Tersusun tanggal.
4. **PreviewScreen** — lihat file (image viewer / pdf viewer / arsip info).

### Mode offline (internal)
- Simpan salinan file + metadata di `sqflite` lokal.
- Timeline bisa berfungsi penuh tanpa internet.
- Saat ada koneksi → sync upload ke server (queue + retry).

---

## 8. Deployment

### Opsi A — Server sendiri (self-host)
- PC/NAS/raspberry di rumah, atau server lokal.
- Jalankan: `node server/src/index.js` (Express + SQLite).
- HP connect via IP LAN, atau tunnel (Tailscale/ngrok) untuk akses dari luar.

### Opsi B — Server langganan (VPS)
- VPS murah (DigitalOcean/Hetzner/Vultr, ~$5-6/bulan) atau hosting Node Indonesia (IDCloudHost, Dewaweb).
- Deploy Express + SQLite + uploads folder. Pasang reverse proxy (Caddy/Nginx) + HTTPS.
- Setup DNS `cloud.mydomain.id`.

### Keamanan deployment
- Wajib HTTPS (Caddy auto-cert).
- JWT expiry + refresh.
- Backup berkala folder `data/` (SQLite + uploads).

---

## 9. Database & Tool tambahan
- `better-sqlite3` — driver SQLite sinkron, ringan, reliable.
- `multer` — upload multipart.
- `jsonwebtoken` — JWT auth.
- `fluent-ffmpeg` (opsional) — thumbnail/kompresi gambar.
- `pdf-parse` / `mammoth` — ekstrak teks pdf/docx untuk search.
- `clamav` (opsional, mode online) — scan virus.

---

## 10. Toko Uji (MVP acceptance)
- [ ] Upload dokumen pdf + pesan "laporan mingguan" → muncul di Chat, ter-save kategori Dokumen, search "laporan" nemu.
- [ ] Upload gambar dari galeri → masuk kategori Gambar, thumbnail tampil, tanggal urut.
- [ ] Upload file .rar → masuk kategori Arsip, tidak dieksekusi, bisa download.
- [ ] Reject .exe dengan pesan error.
- [ ] Search teks → hasil chat + file terkait, cepat (FTS5).
- [ ] Klik file → preview / download.
- [ ] Mode offline: bisa akses file yang sudah ada tanpa internet.
- [ ] (online) file infected diblokir/quarantine.

---

## 11. Roadmap bertahap

### Fase 0 — Fondasi (1-2 hari)
- Inisialisasi repo, stack Express + SQLite, struktur folder, migrasi DB, health endpoint.

### Fase 1 — Core backend (3-4 hari)
- Auth JWT, messages CRUD, upload (whitelist + magic bytes), files list per kategori, download.
- FTS5 search.

### Fase 2 — Mobile MVP (5-7 hari)
- Flutter app: ChatScreen + input + attach, UploadScreen, SearchScreen, FilesScreen (3 tab), PreviewScreen.
- Integrasi REST + upload multipart.

### Fase 3 — Mode offline + polish (2-3 hari)
- Local cache sqflite, sync queue, error handling, loading/empty states, UX ala WA.

### Fase 4 — Deploy (1-2 hari)
- Self-host lokal, atau VPS + HTTPS + backup. Dokumentasi `.bat` launcher (kamu suka launcher sekali-klik).

### Fase 5 — Lanjutan (opsional)
- Multi-user, sharing link, OCR, backup otomatis ke cloud eksternal, notifikasi.

---

## 12. Catatan penting
- File arsip (.rar/.zip) **tidak pernah dieksekusi atau di-unzip otomatis** oleh server — hanya disimpan & didownload. Ini mencegah malware sink.
- Ekstensi whitelist + magic bytes adalah garis pertahanan pertama. ClamAV jadi garis kedua untuk mode online.
- "Search ala WhatsApp" diimplementasikan dengan SQLite FTS5 — sudah optimal untuk skala self-host tanpa perlu server search terpisah.
- Karena aplikasi bersifat internal/personal, model database SQLite (satu file) sudah lebih dari cukup dan paling mudah di-backup.