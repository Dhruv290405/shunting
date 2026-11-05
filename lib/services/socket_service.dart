import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL', defaultValue: 'http://127.0.0.1:5000',
  );
  io.Socket? _socket;
  void Function(String)? onConnectionError;
  void Function(Map<String, dynamic>)? onDeviceStatus;

  void connect({required void Function(Map<String, dynamic>) onTelemetryUpdate}) {
    _socket?.dispose();
    _socket = io.io(baseUrl, <String, dynamic>{
      // Polling works with the threaded Flask server; it upgrades to websocket
      // automatically when simple-websocket/eventlet is installed.
      'transports': ['polling', 'websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 5,
    });
    _socket!.onConnect((_) => _socket!.emit('subscribe_telemetry'));
    _socket!.on('telemetry_update', (data) {
      if (data is Map) onTelemetryUpdate(Map<String, dynamic>.from(data));
    });
    _socket!.on('device_status', (data) {
      if (data is Map) onDeviceStatus?.call(Map<String, dynamic>.from(data));
    });
    _socket!.onConnectError((e) => onConnectionError?.call(e.toString()));
    _socket!.onError((e) => onConnectionError?.call(e.toString()));
    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}