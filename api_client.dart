import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'secure_storage_service.dart';

/// Centralized API Networking Client
/// Automatically attaches Bearer JWT authentication header and handles JSON payloads.
class ApiClient {
  static const String baseUrl = AppConfig.apiBaseUrl;
  static http.Client client = http.Client();

  static Future<Map<String, String>> _getHeaders() async {
    final jwt = await SecureStorageService.getJwt();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (jwt != null) 'Authorization': 'Bearer $jwt',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    return await client.get(uri, headers: headers);
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    return await client.post(uri, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> patch(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    return await client.patch(uri, headers: headers, body: jsonEncode(body));
  }

  static Future<http.Response> delete(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();
    return await client.delete(uri, headers: headers);
  }
}
