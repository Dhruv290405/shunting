import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String lambdaUrl = String.fromEnvironment(
    'LAMBDA_URL',
    defaultValue:
        'https://wmrnfmn54255qt246fn6k5xmby0oebty.lambda-url.ap-south-1.on.aws/',
  );
  static const String lambdaApiKey = String.fromEnvironment('LAMBDA_API_KEY');

  /// Name of the request parameter that carries the device ID.
  static const String deviceIdParam =
      String.fromEnvironment('DEVICE_ID_PARAM', defaultValue: 'deviceId');

  final http.Client _client;
  final String? deviceId;

  ApiService({http.Client? client, this.deviceId})
      : _client = client ?? http.Client();

  Uri _uri({String? requestedDeviceId}) {
    final base = Uri.parse(lambdaUrl);
    return base.replace(queryParameters: {
      ...base.queryParameters,
      if (requestedDeviceId != null) deviceIdParam: requestedDeviceId,
    });
  }

  Future<List<Map<String, dynamic>>> fetchDevices() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (lambdaApiKey.isNotEmpty) headers['x-api-key'] = lambdaApiKey;
    final resp = await _client
        .get(_uri(), headers: headers)
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception(
          'Lambda device list error ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    final body = decoded is Map<String, dynamic> && decoded['body'] is String
        ? jsonDecode(decoded['body'] as String)
        : decoded;
    if (body is! Map<String, dynamic>) {
      return const [];
    }
    if (body['devices'] is! List) {
      final id = body['deviceId'] ?? body['device'];
      if (id == null) return const [];
      final diagnostics = body['diagnostics'];
      final battery = diagnostics is Map ? diagnostics['battery_pct'] : null;
      return [
        {
          'deviceId': id,
          'battery': battery is num ? battery : 0,
          'online': true,
        }
      ];
    }
    return (body['devices'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> fetchTelemetry([String? requestedDeviceId]) async {
    final id = requestedDeviceId ?? deviceId;
    if (id == null || id.isEmpty) {
      throw StateError('Cannot fetch telemetry without a device ID');
    }
    final headers = <String, String>{'Accept': 'application/json'};
    if (lambdaApiKey.isNotEmpty) headers['x-api-key'] = lambdaApiKey;
    final resp = await _client
        .get(_uri(requestedDeviceId: id),
            headers: headers)
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception(
          'Lambda telemetry error ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Lambda telemetry response must be a JSON object');
    }
    final body = decoded['body'];
    if (body is String) {
      final nested = jsonDecode(body);
      if (nested is Map<String, dynamic>) return nested;
    }
    if (body is Map<String, dynamic>) return body;
    return decoded;
  }

  void dispose() {
    _client.close();
  }
}
