import 'dart:math';
import 'dart:typed_data';

/// Cryptographically secure random bytes. Uses [Random.secure], which is backed
/// by the OS CSPRNG on native and by Web Crypto under dart2wasm.
Uint8List secureRandomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}
