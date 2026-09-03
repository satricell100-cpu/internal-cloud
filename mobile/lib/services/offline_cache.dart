import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Cache offline untuk metadata (messages & files) + file biner di lokal.
// Ini memungkinkan aplikasi tetap bisa melihat file yang sudah ter-sync
// saat tidak ada koneksi internet (mode offline / internal).
class OfflineCache {
  static const _kMessagesKey = 'cache_messages';
  static const _kFilesKey = 'cache_files';
  static const _kQueueKey = 'pending_uploads';

  // ── Metadata cache ───────────────────────────────────────────
  static Future<void> cacheMessages(List<dynamic> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMessagesKey, jsonEncode(messages));
  }

  static Future<List<dynamic>?> readCachedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMessagesKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<void> cacheFiles(List<dynamic> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFilesKey, jsonEncode(files));
  }

  static Future<List<dynamic>?> readCachedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kFilesKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── File biner cache (untuk preview offline) ─────────────────
  static Future<File?> getCachedFile(String fileId, String ext) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/cache_$fileId.$ext');
      return await f.exists() ? f : null;
    } catch (_) {
      return null;
    }
  }

  static Future<String> cacheFileBytes(String fileId, String ext, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/cache_$fileId.$ext');
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  // ── Upload queue (pending saat offline) ───────────────────────
  // Simpan daftar upload yang belum bisa dikirim (belum online).
  // Format item: { path, fileName, message }
  static Future<List<Map<String, String>>> getPendingUploads() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueueKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addPendingUpload(
      String path, String fileName, String message) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getPendingUploads();
    queue.add({'path': path, 'fileName': fileName, 'message': message});
    await prefs.setString(_kQueueKey, jsonEncode(queue));
  }

  static Future<void> removePendingUpload(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getPendingUploads();
    if (index >= 0 && index < queue.length) {
      queue.removeAt(index);
      await prefs.setString(_kQueueKey, jsonEncode(queue));
    }
  }
}
