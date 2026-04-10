import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Central API service for all backend communication.
class ApiService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 45);

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  /// Safe on Safari private mode / restricted storage (falls back to no auth header).
  static Future<Map<String, String>> _headers() async {
    String? token;
    try {
      token = await getToken();
    } catch (_) {
      token = null;
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decodeBody(http.Response response) {
    final body = response.body;
    if (body.isEmpty) {
      return {
        'success': false,
        'error': 'Empty response (${response.statusCode})',
      };
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'error': 'Unexpected response shape'};
    } catch (_) {
      return {
        'success': false,
        'error': 'Invalid JSON (${response.statusCode})',
      };
    }
  }

  /// Generic GET request
  static Future<Map<String, dynamic>> get(String url) async {
    try {
      final headers = await _headers();
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(_timeout);
      return _decodeBody(response);
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Check your connection and try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': _friendlyNetworkError(e),
      };
    }
  }

  /// Generic POST request
  static Future<Map<String, dynamic>> post(String url, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decodeBody(response);
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Check your connection and try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': _friendlyNetworkError(e),
      };
    }
  }

  /// Generic PUT request
  static Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final response = await http
          .put(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decodeBody(response);
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Check your connection and try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': _friendlyNetworkError(e),
      };
    }
  }

  /// Generic PATCH request
  static Future<Map<String, dynamic>> patch(String url, Map<String, dynamic> body) async {
    try {
      final headers = await _headers();
      final response = await http
          .patch(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _decodeBody(response);
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Check your connection and try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': _friendlyNetworkError(e),
      };
    }
  }

  /// Generic DELETE request
  static Future<Map<String, dynamic>> delete(String url) async {
    try {
      final headers = await _headers();
      final response = await http
          .delete(Uri.parse(url), headers: headers)
          .timeout(_timeout);
      return _decodeBody(response);
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Request timed out. Check your connection and try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': _friendlyNetworkError(e),
      };
    }
  }

  static String _friendlyNetworkError(Object e) {
    final s = e.toString();
    if (s.contains('ClientException') ||
        s.contains('Load failed') ||
        s.contains('Failed to fetch')) {
      return 'Could not reach the server. Try normal (non-private) Safari/Chrome, '
          'disable VPN/ad blockers, or check that the API is up. '
          'Technical: $s';
    }
    return s;
  }
}
