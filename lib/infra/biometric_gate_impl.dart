import 'package:local_auth/local_auth.dart';

import '../core/ports/biometric_gate.dart';

/// [BiometricGate] backed by `local_auth`.
class BiometricGateImpl implements BiometricGate {
  final LocalAuthentication _auth;

  BiometricGateImpl([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
  }

  @override
  Future<bool> authenticate({required String reason}) {
    return _auth.authenticate(localizedReason: reason, biometricOnly: true);
  }
}
