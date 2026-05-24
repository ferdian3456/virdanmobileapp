import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  SecureStorage(this._inner);

  final FlutterSecureStorage _inner;

  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';

  Future<String?> readAccessToken() => _inner.read(key: _kAccessToken);
  Future<String?> readRefreshToken() => _inner.read(key: _kRefreshToken);

  Future<void> writeTokens({required String accessToken, required String refreshToken}) async {
    await _inner.write(key: _kAccessToken, value: accessToken);
    await _inner.write(key: _kRefreshToken, value: refreshToken);
  }

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
