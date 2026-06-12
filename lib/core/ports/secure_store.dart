/// Secure key-value storage for small secrets, such as the biometric wrapping
/// key. Backed by the OS keychain/keystore on real devices.
abstract interface class SecureStore {
  Future<void> write(String key, String value);

  Future<String?> read(String key);

  Future<void> delete(String key);
}
