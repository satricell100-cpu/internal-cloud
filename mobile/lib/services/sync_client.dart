import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_config.dart';
import 'sync_io.dart' if (dart.library.html) 'sync_web.dart';

// ═══════════════════════════════════════════════════════════════
// WebSocket Sync Client
// Mengelola koneksi WebSocket ke server + menerima push file
//
// Cross-platform: pakai web_socket_channel (IOWebSocketChannel untuk
// mobile/desktop, HtmlWebSocketChannel untuk web). Tidak menyentuh
// dart:io/Platform secara langsung di web, jadi aman di semua platform.
// ═══════════════════════════════════════════════════════════════

typedef OnFileUploaded = void Function(Map<String, dynamic> fileInfo);

class SyncClient {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _heartbeat;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  String? _deviceId;
  OnFileUploaded? onFileUploaded;

  SyncClient() {
    _deviceId = _generateDeviceId();
  }

  String _generateDeviceId() {
    String platform;
    if (kIsWeb) {
      platform = 'web';
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          platform = 'android';
          break;
        case TargetPlatform.iOS:
          platform = 'ios';
          break;
        default:
          platform = 'desktop';
      }
    }
    return '${platform}_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<String?> get _jwtToken async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  bool get isConnected => _channel != null;

  // ═══════════════════════════════════════════════════════════════
  // Connect ke WebSocket server
  // ═══════════════════════════════════════════════════════════════
  Future<void> connect() async {
    if (_intentionalClose) return;
    if (_channel != null) return;

    try {
      final token = await _jwtToken;
      if (token == null || token.isEmpty) return;

      final base = AppConfig.baseUrl;
      final wsUrl = base.replaceFirst('http', 'ws');

      final channel = connectSocket(wsUrl);
      _channel = channel;

      // Register device
      channel.sink.add(jsonEncode({
        'type': 'register',
        'token': token,
        'deviceId': _deviceId,
        'deviceType': kIsWeb ? 'web' : 'mobile',
      }));

      // Handle pesan masuk
      _sub = channel.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data.toString());
            _handleMessage(msg);
          } catch (_) {}
        },
        onDone: () {
          _closeChannel();
          if (!_intentionalClose) _scheduleReconnect();
        },
        onError: (_) {
          _closeChannel();
          if (!_intentionalClose) _scheduleReconnect();
        },
      );

      // Heartbeat tiap 25 detik
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
        _send({'type': 'ping'});
      });

      debugPrint('[SyncClient] Connected');
    } catch (e) {
      debugPrint('[SyncClient] Connection failed: $e');
      _closeChannel();
      _scheduleReconnect();
    }
  }

  void _send(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  // Handle pesan dari server
  // ═══════════════════════════════════════════════════════════════
  void _handleMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'registered':
        debugPrint('[SyncClient] Registered: ${msg["deviceId"]}, devices: ${msg["deviceCount"]}');
        break;

      case 'file_uploaded':
        final file = msg['file'];
        if (file != null && onFileUploaded != null) {
          debugPrint('[SyncClient] New file from other device: ${file["original_name"]}');
          onFileUploaded!(file);
        }
        break;

      case 'pong':
        break;

      default:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Reconnect otomatis
  // ═══════════════════════════════════════════════════════════════
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('[SyncClient] Reconnecting...');
      connect();
    });
  }

  void _closeChannel() {
    try {
      _sub?.cancel();
      _channel?.sink.close();
    } catch (_) {}
    _sub = null;
    _channel = null;
    _heartbeat?.cancel();
  }

  // ═══════════════════════════════════════════════════════════════
  // Disconnect
  // ═══════════════════════════════════════════════════════════════
  void disconnect() {
    _intentionalClose = true;
    _reconnectTimer?.cancel();
    _closeChannel();
  }
}