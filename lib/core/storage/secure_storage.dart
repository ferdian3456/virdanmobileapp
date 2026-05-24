import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage(this._inner);

  final FlutterSecureStorage _inner;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kSignupSessionId = 'signup_session_id';
  static const _kOtpExpiresAt = 'otp_expires_at';

  Future<String?> readAccessToken() => _inner.read(key: _kAccessToken);
  Future<String?> readRefreshToken() => _inner.read(key: _kRefreshToken);

  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {
    await _inner.write(key: _kAccessToken, value: accessToken);
    await _inner.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<String?> readSignupSessionId() => _inner.read(key: _kSignupSessionId);
  Future<void> writeSignupSessionId(String id) => _inner.write(key: _kSignupSessionId, value: id);
  Future<void> deleteSignupSessionId() => _inner.delete(key: _kSignupSessionId);

  Future<int?> readOtpExpiresAt() async {
    final v = await _inner.read(key: _kOtpExpiresAt);
    if (v == null || v.isEmpty) return null;
    return int.tryParse(v);
  }

  Future<void> writeOtpExpiresAt(int unixSeconds) =>
      _inner.write(key: _kOtpExpiresAt, value: unixSeconds.toString());
  Future<void> deleteOtpExpiresAt() => _inner.delete(key: _kOtpExpiresAt);

  Future<void> clear() async {
    await _inner.deleteAll();
  }
}

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(
    const FlutterSecureStorage(
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
    ),
  );
});
