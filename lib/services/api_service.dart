import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android emulator
  // static const String baseUrl = 'http://192.168.1.100:5000/api'; // physical device
  // static const String baseUrl = 'http://localhost:5000/api'; // web / desktop

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<ShuntingDevice>> fetchDevices() async {
    final resp = await _client.get(Uri.parse('$baseUrl/devices'));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = data['devices'] as List<dynamic>;
      return list.map((e) => ShuntingDevice.fromJson(e)).toList();
    }
    throw Exception('Failed to load devices: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> connectDevice(String deviceName) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/connect/$deviceName'),
      headers: {'Content-Type': 'application/json'},
    );
    return _decodeResp(resp);
  }

  Future<Map<String, dynamic>> disconnectDevice() async {
    final resp = await _client.post(Uri.parse('$baseUrl/disconnect'));
    return _decodeResp(resp);
  }

  Future<Map<String, dynamic>> getTelemetry() async {
    final resp = await _client.get(Uri.parse('$baseUrl/telemetry'));
    return _decodeResp(resp);
  }

  Future<Map<String, dynamic>> triggerObstacle() async {
    final resp = await _client.post(Uri.parse('$baseUrl/obstacle'));
    return _decodeResp(resp);
  }

  Future<Map<String, dynamic>> clearObstacle() async {
    final resp = await _client.post(Uri.parse('$baseUrl/clear_obstacle'));
    return _decodeResp(resp);
  }

  Future<Map<String, dynamic>> setCharger(bool plugged) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/charger'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'plugged': plugged}),
    );
    return _decodeResp(resp);
  }

  Future<Map<String, dynamic>> changeDevice(String deviceName) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/change_device/$deviceName'),
      headers: {'Content-Type': 'application/json'},
    );
    return _decodeResp(resp);
  }

  Future<Map<String, dynamic>> getStatus() async {
    final resp = await _client.get(Uri.parse('$baseUrl/status'));
    return _decodeResp(resp);
  }

  Map<String, dynamic> _decodeResp(http.Response resp) {
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('API error ${resp.statusCode}: ${resp.body}');
  }

  void dispose() {
    _client.close();
  }
}