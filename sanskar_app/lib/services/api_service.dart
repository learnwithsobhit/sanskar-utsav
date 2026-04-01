import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Central API service for all backend communication.
class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Generic GET request
  static Future<Map<String, dynamic>> get(String url) async {
    try {
      final headers = await _headers();
      final response = await http.get(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Generic POST request
  static Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Generic PUT request
  static Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Generic PATCH request
  static Future<Map<String, dynamic>> patch(String url, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final response = await http.patch(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Generic DELETE request
  static Future<Map<String, dynamic>> delete(String url) async {
    try {
      final headers = await _headers();
      final response = await http.delete(Uri.parse(url), headers: headers);
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
