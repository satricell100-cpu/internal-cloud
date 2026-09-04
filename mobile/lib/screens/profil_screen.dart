import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_config.dart';
import '../services/app_state.dart';
import '../services/auth_provider.dart';

// Layar Profil & Pengaturan (Murni Akun & Pengaturan)
class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  bool _notificationsEnabled = true;
  String _currentLanguage = 'Indonesia';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadDriveStatus();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _currentLanguage = prefs.getString('app_language') ?? 'Indonesia';
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) {
      setState(() => _notificationsEnabled = value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Notifikasi diaktifkan' : 'Notifikasi dinonaktifkan'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ═══ 1. EDIT PROFIL ═══
  void _showEditProfileDialog() {
    final auth = context.read<AuthProvider>();
    final nameCtrl = TextEditingController(text: auth.user?.displayName ?? '');
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    bool changePassword = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Edit Profil',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Tampilan',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alternate_email, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Username: @${auth.user?.username ?? 'user'}',
                        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Ubah Password', style: TextStyle(fontSize: 15)),
                  value: changePassword,
                  activeColor: const Color(0xFF128C7E),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setModalState(() => changePassword = val),
                ),
                if (changePassword) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: currentPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password Saat Ini',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPassCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password Baru (min. 4 karakter)',
                      prefixIcon: Icon(Icons.lock_reset),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF128C7E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      final newName = nameCtrl.text.trim();
                      final curPass = currentPassCtrl.text;
                      final newPass = newPassCtrl.text;

                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Nama tampilan tidak boleh kosong')),
                        );
                        return;
                      }

                      if (changePassword && (curPass.isEmpty || newPass.length < 4)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password baru minimal 4 karakter dan isi password saat ini')),
                        );
                        return;
                      }

                      Navigator.pop(ctx);

                      final ok = await auth.updateProfile(
                        displayName: newName,
                        currentPassword: changePassword ? curPass : null,
                        newPassword: changePassword ? newPass : null,
                      );

                      if (mounted) {
                        if (ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profil berhasil diperbarui'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(auth.error ?? 'Gagal memperbarui profil'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══ 2. GOOGLE DRIVE ═══
  Future<void> _connectToGoogleDrive() async {
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await appState.getDriveAuthUrl();
      if (url.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Google Drive belum dikonfigurasi di server. Isi GOOGLE_CLIENT_ID & GOOGLE_CLIENT_SECRET di file server/.env'),
          ),
        );
        return;
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) {
        messenger.showSnackBar(const SnackBar(content: Text('Gagal membuka browser untuk login Google')));
      }
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await appState.loadDriveStatus();
        if (appState.driveConnected) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Berhasil terhubung ke Google Drive'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _disconnectGoogleDrive() async {
    final appState = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Putus Google Drive?'),
        content: Text('${appState.driveEmail ?? 'Akun Google'} akan diputus dari penyimpanan Google Drive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Putus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.disconnectDrive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koneksi Google Drive diputus')),
        );
      }
    }
  }

  // ═══ 3. BAGIKAN ═══
  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bagikan Internal Cloud',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Bagikan alamat server atau info akses cloud pribadi ini ke HP lain atau rekan kerja.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.share, color: Color(0xFF128C7E)),
              ),
              title: const Text('Bagikan Info Server & Link'),
              subtitle: Text(AppConfig.baseUrl),
              onTap: () {
                Navigator.pop(ctx);
                Share.share(
                  'Akses Internal Cloud Pribadi:\nAlamat Server: ${AppConfig.baseUrl}\nBuka di browser atau aplikasi Flutter Internal Cloud.',
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.copy, color: Colors.blue),
              ),
              title: const Text('Salin Alamat Server'),
              subtitle: const Text('Salin URL ke clipboard'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: AppConfig.baseUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alamat server disalin ke clipboard!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══ 4. KELOLA PENYIMPANAN ═══
  Future<void> _showStorageManagementDialog() async {
    final appState = context.read<AppState>();
    final imgCount = appState.images.length;
    final docCount = appState.documents.length;
    final arcCount = appState.archives.length;

    int totalBytes = 0;
    for (final f in appState.images) {
      totalBytes += f.sizeBytes;
    }
    for (final f in appState.documents) {
      totalBytes += f.sizeBytes;
    }
    for (final f in appState.archives) {
      totalBytes += f.sizeBytes;
    }

    int cacheBytes = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final list = tempDir.listSync(recursive: true);
        for (final item in list) {
          if (item is File) {
            cacheBytes += await item.length();
          }
        }
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kelola Penyimpanan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF128C7E).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF128C7E).withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done, size: 36, color: Color(0xFF128C7E)),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatBytes(totalBytes),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total ${imgCount + docCount + arcCount} file di Cloud',
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _storageRow('Gambar', '$imgCount file', Icons.image, Colors.teal),
            _storageRow('Dokumen', '$docCount file', Icons.description, Colors.blue),
            _storageRow('Arsip', '$arcCount file', Icons.folder_zip, Colors.orange),
            _storageRow('Cache Lokal Perangkat', _formatBytes(cacheBytes), Icons.cached, Colors.purple),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.cleaning_services, size: 18),
                    label: const Text('Bersihkan Cache'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final tempDir = await getTemporaryDirectory();
                        if (await tempDir.exists()) {
                          tempDir.deleteSync(recursive: true);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cache lokal berhasil dibersihkan!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal bersihkan cache: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF128C7E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.read<AppState>().refreshFiles();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Daftar file diperbarui')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _storageRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }

  // ═══ 5. PILIH BAHASA ═══
  void _showLanguagePicker() {
    final languages = ['Indonesia', 'English'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Bahasa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            return RadioListTile<String>(
              title: Text(lang),
              value: lang,
              groupValue: _currentLanguage,
              activeColor: const Color(0xFF128C7E),
              onChanged: (val) async {
                if (val != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('app_language', val);
                  setState(() => _currentLanguage = val);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Bahasa diubah ke $val')),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // ═══ 6. TENTANG APLIKASI ═══
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF128C7E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud, color: Color(0xFF128C7E), size: 28),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Internal Cloud', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Versi 1.0.0 (Build 1)', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aplikasi cloud pribadi berbasis chat untuk menyimpan, mengorganisir, dan mengelola file secara mandiri dan aman.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Status Server Backend:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Alamat: ${AppConfig.baseUrl}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    const SizedBox(height: 2),
                    const Text('Protokol: REST API + WebSocket Sync', style: TextStyle(fontSize: 11, color: Colors.black87)),
                    const SizedBox(height: 2),
                    const Text('Storage: SQLite + Local Filesystem', style: TextStyle(fontSize: 11, color: Colors.black87)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Fitur Utama:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              _featureItem('Upload chat-based dengan pesan keterangan'),
              _featureItem('Preview instan & buka langsung Word, Excel, PDF'),
              _featureItem('Organisasi otomatis per kategori file'),
              _featureItem('Pencarian cepat nama & konten file'),
              _featureItem('Sinkronisasi Google Drive opsional'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: Color(0xFF128C7E))),
          ),
        ],
      ),
    );
  }

  Widget _featureItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 14, color: Color(0xFF128C7E)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  // ═══ 7. LOGOUT CONFIRMATION ═══
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1073741824) return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '${(b / 1073741824).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & Pengaturan'),
        backgroundColor: const Color(0xFF128C7E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          const SizedBox(height: 24),
          // Avatar + Info Pengguna
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFF128C7E).withOpacity(0.15),
                      child: Text(
                        (auth.user?.displayName ?? 'U').substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF128C7E),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _showEditProfileDialog,
                        child: const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFF128C7E),
                          child: Icon(Icons.edit, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  auth.user?.displayName ?? 'Pengguna',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${auth.user?.username ?? 'user'}@internal.cloud',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(height: 1),

          // ═══ Menu Items ═══
          _MenuItem(
            icon: Icons.person_outline,
            title: 'Edit Profil',
            subtitle: 'Ubah nama tampilan & password',
            onTap: _showEditProfileDialog,
          ),
          _MenuItem(
            icon: Icons.cloud_outlined,
            title: 'Google Drive',
            subtitle: appState.driveConnected
                ? (appState.driveEmail ?? 'Terhubung')
                : 'Belum terhubung',
            trailing: appState.driveConnected
                ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
                : const Icon(Icons.chevron_right),
            onTap: appState.driveConnected
                ? _disconnectGoogleDrive
                : _connectToGoogleDrive,
          ),
          _MenuItem(
            icon: Icons.share_outlined,
            title: 'Bagikan',
            subtitle: 'Bagikan link atau info server cloud',
            onTap: _showShareOptions,
          ),
          _MenuItem(
            icon: Icons.storage_outlined,
            title: 'Penyimpanan',
            subtitle: 'Kelola ruang & bersihkan cache',
            onTap: _showStorageManagementDialog,
          ),
          _MenuItem(
            icon: Icons.notifications_none_outlined,
            title: 'Notifikasi',
            subtitle: _notificationsEnabled ? 'Aktif' : 'Nonaktif',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeColor: const Color(0xFF128C7E),
            ),
            onTap: () => _toggleNotifications(!_notificationsEnabled),
          ),
          _MenuItem(
            icon: Icons.language_outlined,
            title: 'Bahasa',
            subtitle: _currentLanguage,
            onTap: _showLanguagePicker,
          ),
          _MenuItem(
            icon: Icons.info_outline,
            title: 'Tentang',
            subtitle: 'Internal Cloud v1.0.0',
            onTap: _showAboutDialog,
          ),

          const SizedBox(height: 24),

          // ═══ Logout Button ═══
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red, width: 1.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _confirmLogout,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.grey.shade800, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      onTap: onTap,
    );
  }
}
