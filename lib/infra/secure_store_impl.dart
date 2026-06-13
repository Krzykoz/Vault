import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/ports/secure_store.dart';

/// [SecureStore] backed by `flutter_secure_storage` (OS keychain/keystore).
///
/// Entries are bound to the device's currently-enrolled biometrics: reading a
/// value requires a biometric (or device-credential) check enforced by the OS,
/// the data stays on this device (no iCloud sync), and the entry is invalidated
/// automatically if the enrolled biometrics change. Existence checks via
/// [containsKey] inspect only the key, so they never prompt.
class SecureStoreImpl implements SecureStore {
  final FlutterSecureStorage _storage;

  SecureStoreImpl([FlutterSecureStorage? storage])
      : _storage = storage ?? _biometricStorage();

  static FlutterSecureStorage _biometricStorage() {
    return const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
        accessControlFlags: [AccessControlFlag.biometryCurrentSet],
      ),
      mOptions: MacOsOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
        accessControlFlags: [AccessControlFlag.biometryCurrentSet],
      ),
      aOptions: AndroidOptions.biometric(
        enforceBiometrics: true,
        biometricType: AndroidBiometricType.strongBiometricOnly,
      ),
    );
  }

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<bool> containsKey(String key) => _storage.containsKey(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
