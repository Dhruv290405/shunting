import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  static const String wsUrl = 'ws://localhost:5000';

  WebSocketChannel? _channel;

  void connect({required void Function(dynamic) onTelemetryUpdate}) {
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel!.stream.listen(
      (data) {
        final msg = jsonDecode(data) as Map<String, dynamic>;
        final type = msg['type'] ?? msg['event'];
        if (type == 'telemetry_update' || msg.containsKey('distance')) {
          onTelemetryUpdate(msg);
        }
      },
      onError: (err) => print('Socket error: $err'),
      onDone: () => print('Socket disconnected'),
    );
    _channel!.sink.add(jsonEncode({'event': 'subscribe_telemetry'}));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}