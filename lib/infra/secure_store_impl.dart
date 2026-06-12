import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/ports/secure_store.dart';

/// [SecureStore] backed by `flutter_secure_storage` (OS keychain/keystore).
class SecureStoreImpl implements SecureStore {
  final FlutterSecureStorage _storage;

  SecureStoreImpl([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
