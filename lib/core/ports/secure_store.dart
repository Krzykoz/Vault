/// Secure key-value storage for small secrets, such as the biometric wrapping
/// key. Backed by the OS keychain/keystore on real devices.
abstract interface class SecureStore {
  Future<void> write(String key, String value);

  /// Reads a stored value. For biometric-bound entries this triggers the OS
  /// biometric prompt, and may throw if the user cancels or the entry was
  /// invalidated. Returns null when the entry is absent.
  Future<String?> read(String key);

  /// Whether an entry exists. This does not decrypt the value, so it never
  /// triggers a biometric prompt.
  Future<bool> containsKey(String key);

  Future<void> delete(String key);
}
