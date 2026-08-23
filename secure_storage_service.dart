import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage Service
/// Manages 90-day persistent JWT tokens, refresh tokens, and user credentials
/// using Android Keystore and iOS Keychain.
/// Source of Truth: Section 4 — Step 2 (JWT Token Management)
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keyJwtToken = 'jwt_access_token';
  static const String _keyRefreshToken = 'jwt_refresh_token';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserRole = 'auth_user_role';
  static const String _keyBiometricEnabled = 'biometric_lock_enabled';
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding';

  // ─── JWT Access Token ─────────────────────────────────────────

  static Future<void> setJwt(String token) async => await saveJwt(token);

  static Future<void> saveJwt(String token) async {
    try {
      await _storage.write(key: _keyJwtToken, value: token);
    } catch (_) {}
  }

  static Future<String?> getJwt() async {
    try {
      return await _storage.read(key: _keyJwtToken);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
    } catch (_) {}
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  // ─── User Profile Cache ───────────────────────────────────────

  static Future<void> saveUserSession({
    required String userId,
    required String role,
    required String jwt,
    String? refreshToken,
  }) async {
    try {
      await _storage.write(key: _keyUserId, value: userId);
      await _storage.write(key: _keyUserRole, value: role);
      await _storage.write(key: _keyJwtToken, value: jwt);
      if (refreshToken != null) {
        await _storage.write(key: _keyRefreshToken, value: refreshToken);
      }
    } catch (_) {}
  }

  static Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _keyUserId);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getUserRole() async {
    try {
      return await _storage.read(key: _keyUserRole);
    } catch (_) {
      return null;
    }
  }

  // ─── Biometrics & Security ────────────────────────────────────

  static Future<void> setBiometricEnabled(bool enabled) async {
    try {
      await _storage.write(key: _keyBiometricEnabled, value: enabled.toString());
    } catch (_) {}
  }

  static Future<bool> isBiometricEnabled() async {
    try {
      final value = await _storage.read(key: _keyBiometricEnabled);
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  // ─── Onboarding State ─────────────────────────────────────────

  static Future<void> setOnboardingSeen(bool seen) async => await setHasSeenOnboarding(seen);

  static Future<bool> isOnboardingSeen() async => await hasSeenOnboarding();

  static Future<void> setHasSeenOnboarding(bool seen) async {
    try {
      await _storage.write(key: _keyHasSeenOnboarding, value: seen.toString());
    } catch (_) {}
  }

  static Future<bool> hasSeenOnboarding() async {
    try {
      final value = await _storage.read(key: _keyHasSeenOnboarding);
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  // ─── Clear All / Logout ───────────────────────────────────────

  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}
  }
}
