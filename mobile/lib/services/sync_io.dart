// Varian IO (mobile/desktop): pakai dart:io WebSocket via web_socket_channel
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

WebSocketChannel connectSocket(String url) {
  return IOWebSocketChannel.connect(url);
}