import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
// SMART NETWORK AUTO-DETECT
//
// Logika otomatis:
// 1. Coba ping server lokal WLAN (misalnya 192.168.1.21:3000)
//    dengan timeout sangat singkat (1.5 detik)
// 2. Jika berhasil → gunakan WLAN (lebih cepat, tanpa internet)
// 3. Jika gagal (beda jaringan/di luar rumah) → pakai cloud Railway
// ═══════════════════════════════════════════════════════════════

class AppConfig {
  /// URL server lokal saat di jaringan WiFi yang sama dengan laptop
  static const String localUrl = 'http://192.168.1.21:3000';

  /// URL server cloud Railway (selalu aktif, bisa diakses dari mana saja)
  static const String cloudUrl =
      'https://internal-cloud-production.up.railway.app';

  /// Timeout untuk cek koneksi lokal (singkat agar tidak lambat)
  static const Duration _detectTimeout = Duration(milliseconds: 1500);

  /// Key untuk SharedPreferences cache
  static const String _prefKey = 'resolved_base_url';
  static const String _prefExpiry = 'resolved_base_url_expiry';

  /// URL yang sedang aktif (diisi setelah detect())
  static String? _resolvedUrl;

  /// Mode koneksi saat ini
  static String connectionMode = 'detecting...';

  /// Ambil baseUrl aktif (panggil setelah detect())
  static String get baseUrl {
    return _resolvedUrl ?? cloudUrl; // Fallback ke cloud jika belum detect
  }

  /// Deteksi otomatis jaringan dan tentukan server yang dipakai.
  /// Panggil sekali saat app start (di main.dart atau splash screen).
  static Future<void> detect() async {
    // Cek cache dulu (berlaku 60 detik agar tidak ping terus)
    final prefs = await SharedPreferences.getInstance();
    final expiry = prefs.getInt(_prefExpiry) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now < expiry && prefs.containsKey(_prefKey)) {
      _resolvedUrl = prefs.getString(_prefKey);
      connectionMode = _resolvedUrl == localUrl ? 'WLAN Lokal' : 'Cloud Railway';
      return;
    }

    // Coba ping server lokal
    try {
      final response = await http
          .get(Uri.parse('$localUrl/api/health'))
          .timeout(_detectTimeout);

      if (response.statusCode == 200) {
        _resolvedUrl = localUrl;
        connectionMode = 'WLAN Lokal 🟢';
        await _saveCache(localUrl, prefs);
        return;
      }
    } on SocketException {
      // Tidak terhubung ke jaringan lokal
    } on HttpException {
      // Server lokal tidak merespons
    } catch (_) {
      // Timeout atau error lain
    }

    // Fallback ke cloud
    _resolvedUrl = cloudUrl;
    connectionMode = 'Cloud Railway 🌐';
    await _saveCache(cloudUrl, prefs);
  }

  static Future<void> _saveCache(String url, SharedPreferences prefs) async {
    await prefs.setString(_prefKey, url);
    // Cache berlaku 60 detik
    await prefs.setInt(
      _prefExpiry,
      DateTime.now().millisecondsSinceEpoch + 60000,
    );
  }

  /// Reset cache agar deteksi ulang saat dipanggil [detect()] berikutnya.
  static Future<void> resetDetection() async {
    _resolvedUrl = null;
    connectionMode = 'detecting...';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    await prefs.remove(_prefExpiry);
  }
}
