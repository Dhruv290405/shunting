import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String lambdaUrl = String.fromEnvironment(
    'LAMBDA_URL',
    defaultValue: 'https://wmrnfmn54255qt246fn6k5xmby0oebty.lambda-url.ap-south-1.on.aws/',
  );
  static const String lambdaApiKey = String.fromEnvironment('LAMBDA_API_KEY');

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> fetchTelemetry() async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (lambdaApiKey.isNotEmpty) headers['x-api-key'] = lambdaApiKey;
    final resp = await _client
        .get(Uri.parse(lambdaUrl), headers: headers)
        .timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) {
      throw Exception('Lambda telemetry error ${resp.statusCode}: ${resp.body}');
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