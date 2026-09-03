// Varian Web: pakai web_socket_channel HtmlWebSocketChannel (aman di browser)
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/html.dart';

WebSocketChannel connectSocket(String url) {
  return HtmlWebSocketChannel.connect(url);
}