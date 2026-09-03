import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../models/message.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'offline_cache.dart';
import 'sync_client.dart';

// Manajemen state data aplikasi (pesan, file, search) dengan dukungan OFFLINE:
// - Saat online: ambil dari server + simpan cache lokal
// - Saat offline (network error): baca dari cache lokal agar tetap bisa lihat
// - Upload saat offline: masuk antrian (pending), sinkron otomatis saat online
class AppState extends ChangeNotifier {
  List<Message> _messages = [];
  List<FileItem> _allFiles = [];
  List<FileItem> _images = [];
  List<FileItem> _documents = [];
  List<FileItem> _archives = [];
  List<SearchResult> _searchResults = [];
  bool _isLoading = false;
  bool _isOnline = true;
  String? _error;
  int _pendingCount = 0;
  int _activeTabIndex = 0;
  String? _selectedMessageId;
  String? _selectedFileId;
  String? _highlightMessageId;
  bool _driveConnected = false;
  String? _driveEmail;
  bool _driveLoading = false;
  final SyncClient _sync = SyncClient();

  String? get highlightMessageId => _highlightMessageId;

  List<Message> get messages => _messages;
  List<FileItem> get allFiles => _allFiles;
  List<FileItem> get images => _images;
  List<FileItem> get documents => _documents;
  List<FileItem> get archives => _archives;
  List<SearchResult> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isOnline => _isOnline;
  String? get error => _error;
  int get pendingCount => _pendingCount;
  int get activeTabIndex => _activeTabIndex;
  String? get selectedMessageId => _selectedMessageId;
  String? get selectedFileId => _selectedFileId;
  bool get driveConnected => _driveConnected;
  String? get driveEmail => _driveEmail;
  bool get driveLoading => _driveLoading;

  // ── Google Drive ─────────────────────────────────────────────
  Future<void> loadDriveStatus() async {
    _driveLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getDriveStatus();
      _driveConnected = data['connected'] == true;
      _driveEmail = data['email'] as String?;
    } catch (_) {
      _driveConnected = false;
      _driveEmail = null;
    }
    _driveLoading = false;
    notifyListeners();
  }

  Future<String> getDriveAuthUrl() async {
    return ApiService.getDriveAuthUrl();
  }

  Future<void> disconnectDrive() async {
    try {
      await ApiService.disconnectDrive();
      _driveConnected = false;
      _driveEmail = null;
    } catch (_) {}
    notifyListeners();
  }

  // ── Load semua data (online-first, fallback ke cache) ────────
  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadMessages(),
        _loadFiles(),
      ]);
      _attachFilesToMessages();
      _isOnline = true;
      // Simpan ke cache untuk mode offline
      await _saveCache();
    } catch (e) {
      // Gagal ambil dari server → baca dari cache (mode offline)
      _isOnline = false;
      await _loadFromCache();
      if (_messages.isEmpty && _allFiles.isEmpty) {
        _error = e.toString().replaceAll('Exception: ', '');
      }
    } finally {
      _pendingCount = (await OfflineCache.getPendingUploads()).length;
      _isLoading = false;
      notifyListeners();
    }

    // Auto-connect WebSocket sync (agar bisa terima file dari web/HP lain)
    _sync.onFileUploaded = (fileInfo) async {
      // File baru dari device lain → refresh data dari server
      debugPrint('[AppState] Sync: new file from other device, refreshing...');
      await _loadMessages();
      await _loadFiles();
      _attachFilesToMessages();
      notifyListeners();
    };
    _sync.connect();
  }

  Future<void> _loadMessages() async {
    final data = await ApiService.getMessages();
    _messages = data
        .map((m) => Message.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  Future<void> _loadFiles() async {
    final data = await ApiService.getFiles();
    _allFiles =
        data.map((f) => FileItem.fromJson(f as Map<String, dynamic>)).toList();
    _images = _allFiles.where((f) => f.category == 'image').toList();
    _documents = _allFiles.where((f) => f.category == 'document').toList();
    _archives = _allFiles.where((f) => f.category == 'archive').toList();
  }

  void _attachFilesToMessages() {
    final byMessage = <String, List<FileItem>>{};
    for (final f in _allFiles) {
      final mid = f.messageId;
      if (mid == null) continue;
      byMessage.putIfAbsent(mid, () => []).add(f);
    }
    _messages = _messages.map((m) {
      final files = byMessage[m.id] ?? const [];
      return Message(
        id: m.id,
        body: m.body,
        ts: m.ts,
        date: m.date,
        fileCount: m.fileCount,
        files: files,
      );
    }).toList();
  }

  // Baca dari cache lokal (offline)
  Future<void> _loadFromCache() async {
    final cachedMessages = await OfflineCache.readCachedMessages();
    if (cachedMessages != null) {
      _messages = cachedMessages
          .map((m) => Message.fromJson(m as Map<String, dynamic>))
          .toList();
    }
    final cachedFiles = await OfflineCache.readCachedFiles();
    if (cachedFiles != null) {
      _allFiles = cachedFiles
          .map((f) => FileItem.fromJson(f as Map<String, dynamic>))
          .toList();
      _images = _allFiles.where((f) => f.category == 'image').toList();
      _documents = _allFiles.where((f) => f.category == 'document').toList();
      _archives = _allFiles.where((f) => f.category == 'archive').toList();
      _attachFilesToMessages();
    }
  }

  Future<void> _saveCache() async {
    await OfflineCache.cacheMessages(
        _messages.map((m) => m.toJson()).toList());
    await OfflineCache.cacheFiles(
        _allFiles.map((f) => f.toJson()).toList());
  }

  Future<void> refreshFiles() async {
    try {
      await _loadFiles();
      _isOnline = true;
      await OfflineCache.cacheFiles(_allFiles.map((f) => f.toJson()).toList());
    } catch (_) {
      _isOnline = false;
    }
    notifyListeners();
  }

  // ── Kirim pesan text ──────────────────────────────────────────
  Future<void> sendTextMessage(String body) async {
    try {
      await ApiService.sendMessage(body);
      await _loadMessages();
      _attachFilesToMessages();
      await OfflineCache.cacheMessages(
          _messages.map((m) => m.toJson()).toList());
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      rethrow;
    }
    notifyListeners();
  }

  // ── Upload file + pesan (offline -> queue) ────────────────────
  Future<void> uploadFile(
    File file,
    String fileName,
    String message, {
    Uint8List? bytes,
    bool saveToDrive = false,
  }) async {
    try {
      await ApiService.uploadFile(file, fileName, message,
          bytes: bytes, saveToDrive: saveToDrive);
      await Future.wait([_loadMessages(), _loadFiles()]);
      _attachFilesToMessages();
      await _saveCache();
      _isOnline = true;
    } catch (e) {
      // Offline → masukkan ke antrian pending
      _isOnline = false;
      await OfflineCache.addPendingUpload(file.path, fileName, message);
      _pendingCount = (await OfflineCache.getPendingUploads()).length;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  Future<void> uploadFileBytes(
    Uint8List bytes,
    String fileName,
    String message, {
    bool saveToDrive = false,
  }) async {
    try {
      await ApiService.uploadFile(File(fileName), fileName, message,
          bytes: bytes, saveToDrive: saveToDrive);
      await Future.wait([_loadMessages(), _loadFiles()]);
      _attachFilesToMessages();
      await _saveCache();
      _isOnline = true;
    } catch (e) {
      _isOnline = false;
      // Web tidak punya file.path; simpan metadata placeholder agar queue tetap aman.
      await OfflineCache.addPendingUpload('/web/$fileName', fileName, message);
      _pendingCount = (await OfflineCache.getPendingUploads()).length;
      notifyListeners();
      rethrow;
    }
    notifyListeners();
  }

  // ── Sync antrian upload (panggil saat koneksi kembali) ────────
  Future<void> syncPending() async {
    final queue = await OfflineCache.getPendingUploads();
    if (queue.isEmpty) return;

    // Proses satu per satu; yang berhasil dihapus dari antrian
    for (int i = 0; i < queue.length; i++) {
      final item = queue[i];
      try {
        final f = File(item['path']!);
        if (!await f.exists()) {
          await OfflineCache.removePendingUpload(i);
          continue;
        }
        await ApiService.uploadFile(
          f,
          item['fileName']!,
          item['message'] ?? '',
        );
        await OfflineCache.removePendingUpload(i);
      } catch (_) {
        // Gagal (masih offline / error) — stop, tunggu percobaan berikutnya
        break;
      }
    }

    await Future.wait([_loadMessages(), _loadFiles()]);
    _attachFilesToMessages();
    await _saveCache();
    _pendingCount = (await OfflineCache.getPendingUploads()).length;
    _isOnline = true;
    notifyListeners();
  }

  // ── Pencarian ─────────────────────────────────────────────────
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    try {
      final data = await ApiService.search(query);
      _searchResults = data
          .map((r) => SearchResult.fromJson(r as Map<String, dynamic>))
          .toList();
      _isOnline = true;
    } catch (_) {
      _isOnline = false;
      throw Exception('Sedang offline. Cari coba lagi saat online.');
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  void openSearchResult(SearchResult r) {
    final targetId = r.messageId ?? r.id;
    if (targetId == null || targetId.isEmpty) return;
    _selectedMessageId = targetId;
    _selectedFileId = r.id;
    _highlightMessageId = targetId;
    _activeTabIndex = 0;
    notifyListeners();
  }

  void showChatTarget({required String messageId, String? fileId}) {
    _selectedMessageId = messageId;
    _selectedFileId = fileId;
    _highlightMessageId = messageId;
    _activeTabIndex = 0;
    notifyListeners();
  }

  void clearChatTarget() {
    _selectedMessageId = null;
    _selectedFileId = null;
    _highlightMessageId = null;
    notifyListeners();
  }

  void setActiveTab(int index) {
    _activeTabIndex = index;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// ===== extension: helper serialization untuk cache =====
extension on Message {
  Map<String, dynamic> toJson() => {
        'id': id,
        'body': body,
        'ts': ts,
        'date': date,
        'file_count': fileCount,
        'files': files.map((f) => f.toJson()).toList(),
      };
}

extension on FileItem {
  Map<String, dynamic> toJson() => {
        'id': id,
        'message_id': messageId,
        'original_name': originalName,
        'mime': mime,
        'category': category,
        'size_bytes': sizeBytes,
        'ts': ts,
        'download_url': downloadUrl,
        'preview_url': previewUrl,
      };
}
