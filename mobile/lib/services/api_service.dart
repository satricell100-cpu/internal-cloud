import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:path_provider/path_provider.dart';
import 'app_config.dart';

// Layanan komunikasi dengan backend Internal Cloud
// Semua endpoint di sini sesuai dengan API di server (src/routes/)
class ApiService {
  static const String baseUrl = AppConfig.baseUrl;

  // ── Token management ──────────────────────────────────────────
  static String? cachedToken;

  static Future<void> saveToken(String token) async {
    cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<String?> getToken() async {
    if (cachedToken != null) return cachedToken;
    final prefs = await SharedPreferences.getInstance();
    cachedToken = prefs.getString('auth_token');
    return cachedToken;
  }

  static Future<void> clearToken() async {
    cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  static String getRawImageUrl(String fileId) {
    if (cachedToken != null && cachedToken!.isNotEmpty) {
      return '$baseUrl/api/files/$fileId/raw?token=${Uri.encodeQueryComponent(cachedToken!)}';
    }
    return '$baseUrl/api/files/$fileId/raw';
  }

  static Map<String, String> getImageHeaders() {
    if (cachedToken != null && cachedToken!.isNotEmpty) {
      return {'Authorization': 'Bearer $cachedToken'};
    }
    return {};
  }

  static Map<String, String> _headers([String? token]) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final t = token ?? cachedToken;
    if (t != null) h['Authorization'] = 'Bearer $t';
    return h;
  }

  // ── AUTH ──────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> register(
    String username,
    String password,
    String displayName,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'username': username,
        'password': password,
        'display_name': displayName,
      }),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  static Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? currentPassword,
    String? newPassword,
  }) async {
    final token = await getToken();
    final res = await http.put(
      Uri.parse('$baseUrl/api/auth/profile'),
      headers: _headers(token),
      body: jsonEncode({
        if (displayName != null) 'display_name': displayName,
        if (currentPassword != null) 'current_password': currentPassword,
        if (newPassword != null) 'new_password': newPassword,
      }),
    );
    return _parse(res);
  }

  // ── MESSAGES ──────────────────────────────────────────────────
  static Future<List<dynamic>> getMessages({
    int limit = 50,
    int offset = 0,
  }) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/messages?limit=$limit&offset=$offset'),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['messages'] ?? [];
  }

  static Future<Map<String, dynamic>> sendMessage(String body) async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/messages'),
      headers: _headers(token),
      body: jsonEncode({'body': body}),
    );
    return _parse(res);
  }

  // ── FILES ─────────────────────────────────────────────────────
  static Future<List<dynamic>> getFiles({String? category}) async {
    final token = await getToken();
    final url = category != null
        ? '$baseUrl/api/files?category=$category'
        : '$baseUrl/api/files';
    final res = await http.get(Uri.parse(url), headers: _headers(token));
    final data = _parse(res);
    return data['files'] ?? [];
  }

  static Future<List<dynamic>> getCategories() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/files/categories'),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['categories'] ?? [];
  }

  // ── UPLOAD (multipart: file + pesan) ──────────────────────────
  static Future<Map<String, dynamic>> uploadFile(
    dynamic fileSource,
    String fileName,
    String message, {
    Uint8List? bytes,
    bool saveToDrive = false,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    } else if (fileSource is File) {
      request.files.add(
        await http.MultipartFile.fromPath('file', fileSource.path, filename: fileName),
      );
    } else {
      throw Exception('Upload membutuhkan File atau bytes');
    }

    request.fields['message'] = message;
    request.fields['save_to_drive'] = saveToDrive ? 'true' : 'false';

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  // ── SEARCH ────────────────────────────────────────────────────
  static Future<List<dynamic>> search(String query) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/search?q=${Uri.encodeQueryComponent(query)}'),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['results'] ?? [];
  }

  // ── DOWNLOAD / RAW ────────────────────────────────────────────
  // Mendapatkan info metadata satu file
  static Future<Map<String, dynamic>> getFileInfo(String fileId) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/files/$fileId'),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['file'] as Map<String, dynamic>? ?? {};
  }

  // Mengunduh file dan menyimpannya ke direktori dokumen
  static Future<String> downloadFile(String fileId, String fileName) async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/files/$fileId/download'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception('Gagal mengunduh file: ${res.statusCode}');
    }
    final dir = await _getDownloadDir();
    final path = '$dir/$fileName';
    final f = File(path);
    await f.writeAsBytes(res.bodyBytes);
    return path;
  }

  static Future<String> _getDownloadDir() async {
    try {
      final publicDownload = Directory('/storage/emulated/0/Download');
      if (await publicDownload.exists()) return publicDownload.path;
      final extDir = await getExternalStorageDirectory();
      if (extDir != null && await extDir.exists()) return extDir.path;
      final appDoc = await getApplicationDocumentsDirectory();
      return appDoc.path;
    } catch (_) {
      final temp = await getTemporaryDirectory();
      return temp.path;
    }
  }

  // ── GOOGLE DRIVE ────────────────────────────────────────────
  // Ambil URL otorisasi Google Drive
  static Future<String> getDriveAuthUrl() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/drive/auth-url'),
      headers: _headers(token),
    );
    final data = _parse(res);
    return data['authUrl'] as String? ?? '';
  }

  // Cek status koneksi Google Drive
  static Future<Map<String, dynamic>> getDriveStatus() async {
    final token = await getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/api/drive/status'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Putus koneksi Google Drive
  static Future<Map<String, dynamic>> disconnectDrive() async {
    final token = await getToken();
    final res = await http.post(
      Uri.parse('$baseUrl/api/drive/disconnect'),
      headers: _headers(token),
    );
    return _parse(res);
  }

  // Upload file ke Google Drive (di luar alur upload chat)
  static Future<Map<String, dynamic>> uploadToDrive(
    dynamic fileSource,
    String fileName, {
    Uint8List? bytes,
  }) async {
    final token = await getToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/drive/upload'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    if (bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );
    } else if (fileSource is File) {
      request.files.add(
        await http.MultipartFile.fromPath('file', fileSource.path, filename: fileName),
      );
    } else {
      throw Exception('Upload Drive membutuhkan File atau bytes');
    }
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _parse(res);
  }

  // ── HELPERS ───────────────────────────────────────────────────
  static Map<String, dynamic> _parse(http.Response res) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respons server tidak valid (${res.statusCode})');
    }
    if (res.statusCode >= 400) {
      throw Exception(json['error'] ?? 'Terjadi kesalahan (${res.statusCode})');
    }
    return json;
  }
}
