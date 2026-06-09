import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecretPinStorage {
  static const _key = 'secret_pin_number';

  final FlutterSecureStorage _storage;

  SecretPinStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> hasSecret() async {
    final value = await _storage.read(key: _key);
    return value != null && value.isNotEmpty;
  }

  Future<String?> getSecret() => _storage.read(key: _key);

  Future<void> saveSecret(String secret) =>
      _storage.write(key: _key, value: secret);

  Future<void> clearSecret() => _storage.delete(key: _key);
}
