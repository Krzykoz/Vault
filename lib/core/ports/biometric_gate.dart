/// Device biometric authentication (Face ID / Touch ID / fingerprint).
abstract interface class BiometricGate {
  /// Whether biometric authentication is available and enrolled on this device.
  Future<bool> isAvailable();

  /// Prompts the user. Returns true only on a successful authentication.
  Future<bool> authenticate({required String reason});
}
