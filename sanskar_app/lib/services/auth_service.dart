import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/guest.dart';
import 'api_service.dart';

/// Outcome of code/token login when server may require OTP instead.
enum AuthLoginOutcome {
  success,
  otpRequired,
  failed,
}

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

  /// Login with invite code (legacy). Returns outcome; [errorMessage] set when failed.
  Future<(AuthLoginOutcome outcome, String? errorMessage)> loginWithInviteCode(
    String inviteCode,
  ) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post(ApiConfig.authLogin, {
      'invite_code': inviteCode.trim(),
    });

    _isLoading = false;
    notifyListeners();

    if (result['success'] == true) {
      await ApiService.saveToken(result['token']);
      _currentGuest = Guest.fromJson(result['guest']);
      _isLoggedIn = true;
      notifyListeners();
      return (AuthLoginOutcome.success, null);
    }

    if (result['otp_required'] == true) {
      return (AuthLoginOutcome.otpRequired, null);
    }

    return (AuthLoginOutcome.failed, result['error']?.toString() ?? 'Login failed');
  }

  /// Redeem opaque invite token from link/QR.
  Future<(AuthLoginOutcome outcome, String? errorMessage)> redeemInviteToken(
    String inviteToken,
  ) async {
    _isLoading = true;
    notifyListeners();

    final result = await ApiService.post(ApiConfig.authRedeemInvite, {
      'invite_token': inviteToken.trim(),
    });

    _isLoading = false;
    notifyListeners();

    if (result['success'] == true) {
      await ApiService.saveToken(result['token']);
      _currentGuest = Guest.fromJson(result['guest']);
      _isLoggedIn = true;
      notifyListeners();
      return (AuthLoginOutcome.success, null);
    }

    if (result['otp_required'] == true) {
      return (AuthLoginOutcome.otpRequired, null);
    }

    return (AuthLoginOutcome.failed, result['error']?.toString() ?? 'Invalid invite link');
  }

  /// Request OTP (SMS or WhatsApp per server config). On success, [deliveryChannel] is `whatsapp`, `sms`, or `none`.
  Future<(String? errorMessage, String? deliveryChannel)> requestOtp({
    required String phoneE164,
    String? inviteToken,
    String? inviteCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    final body = <String, dynamic>{'phone': phoneE164.trim()};
    if (inviteToken != null && inviteToken.trim().isNotEmpty) {
      body['invite_token'] = inviteToken.trim();
    }
    if (inviteCode != null && inviteCode.trim().isNotEmpty) {
      body['invite_code'] = inviteCode.trim();
    }

    final result = await ApiService.post(ApiConfig.authOtpRequest, body);

    _isLoading = false;
    notifyListeners();

    if (result['success'] == true) {
      final ch = result['delivery_channel']?.toString();
      return (null, ch);
    }
    return (result['error']?.toString() ?? 'Could not send code', null);
  }

  /// Verify OTP and open session.
  Future<String?> verifyOtp({
    required String phoneE164,
    required String otp,
    String? inviteToken,
    String? inviteCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    final body = <String, dynamic>{
      'phone': phoneE164.trim(),
      'otp': otp.trim(),
    };
    if (inviteToken != null && inviteToken.trim().isNotEmpty) {
      body['invite_token'] = inviteToken.trim();
    }
    if (inviteCode != null && inviteCode.trim().isNotEmpty) {
      body['invite_code'] = inviteCode.trim();
    }

    final result = await ApiService.post(ApiConfig.authOtpVerify, body);

    _isLoading = false;
    notifyListeners();

    if (result['success'] == true) {
      await ApiService.saveToken(result['token']);
      _currentGuest = Guest.fromJson(result['guest']);
      _isLoggedIn = true;
      notifyListeners();
      return null;
    }

    return result['error']?.toString() ?? 'Verification failed';
  }

  /// Backwards-compatible: invite code only.
  Future<String?> login(String inviteCode) async {
    final (outcome, err) = await loginWithInviteCode(inviteCode);
    if (outcome == AuthLoginOutcome.success) return null;
    if (outcome == AuthLoginOutcome.otpRequired) {
      return 'OTP_REQUIRED';
    }
    return err;
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
