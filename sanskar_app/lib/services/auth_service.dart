import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/guest.dart';
import 'api_service.dart';

/// Manages authentication state.
class AuthService extends ChangeNotifier {
  Guest? _currentGuest;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  Guest? get currentGuest => _currentGuest;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _currentGuest?.isAdmin ?? false;

  /// Try auto-login with stored token.
  Future<bool> tryAutoLogin() async {
    final token = await ApiService.getToken();
    if (token == null) return false;

    _isLoading = true;
    notifyListeners();

    final result = await ApiService.get(ApiConfig.authMe);

    _isLoading = false;

    if (result['success'] == true && result['guest'] != null) {
      _currentGuest = Guest.fromJson(result['guest']);
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }

    await ApiService.clearToken();
    notifyListeners();
    return false;
  }

  /// Login with invite code.
  Future<String?> login(String inviteCode) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post(ApiConfig.authLogin, {
      'invite_code': inviteCode,
    });

    _isLoading = false;

    if (result['success'] == true) {
      await ApiService.saveToken(result['token']);
      _currentGuest = Guest.fromJson(result['guest']);
      _isLoggedIn = true;
      notifyListeners();
      return null; // success
    }

    notifyListeners();
    return result['error'] ?? 'Login failed';
  }

  /// Logout.
  Future<void> logout() async {
    await ApiService.post(ApiConfig.authLogout, {});
    await ApiService.clearToken();
    _currentGuest = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  /// Refresh guest data.
  Future<void> refreshProfile() async {
    final result = await ApiService.get(ApiConfig.authMe);
    if (result['success'] == true && result['guest'] != null) {
      _currentGuest = Guest.fromJson(result['guest']);
      notifyListeners();
    }
  }
}
