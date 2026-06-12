import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Argon2id cost parameters. Defaults follow OWASP's Argon2id recommendation
/// (m=19456 KiB, t=2, p=1, 32-byte output). These get tuned for real devices in
/// the performance spike task; they are stored alongside each vault so a file
/// can always be re-derived with the parameters it was created with.
class Argon2Params {
  /// Number of lanes (p).
  final int parallelism;

  /// Memory cost in KiB (m).
  final int memory;

  /// Number of passes (t).
  final int iterations;

  /// Derived key length in bytes.
  final int hashLength;

  const Argon2Params({
    this.parallelism = 1,
    this.memory = 19456,
    this.iterations = 2,
    this.hashLength = 32,
  });

  /// Deliberately weak parameters for fast tests. Never use in production.
  const Argon2Params.forTesting()
      : parallelism = 1,
        memory = 256,
        iterations = 1,
        hashLength = 32;

  Map<String, dynamic> toMap() => {
        'parallelism': parallelism,
        'memory': memory,
        'iterations': iterations,
        'hashLength': hashLength,
      };

  factory Argon2Params.fromMap(Map<String, dynamic> map) => Argon2Params(
        parallelism: map['parallelism'] as int,
        memory: map['memory'] as int,
        iterations: map['iterations'] as int,
        hashLength: map['hashLength'] as int,
      );

  @override
  bool operator ==(Object other) =>
      other is Argon2Params &&
      other.parallelism == parallelism &&
      other.memory == memory &&
      other.iterations == iterations &&
      other.hashLength == hashLength;

  @override
  int get hashCode => Object.hash(parallelism, memory, iterations, hashLength);
}

/// Derives an encryption key from a password and salt using Argon2id.
class Kdf {
  final Argon2Params params;

  const Kdf([this.params = const Argon2Params()]);

  /// Returns the derived key bytes for [password] and [salt]. The same inputs
  /// and parameters always yield the same key.
  Future<List<int>> deriveKey({
    required String password,
    required List<int> salt,
  }) async {
    final algorithm = Argon2id(
      parallelism: params.parallelism,
      memory: params.memory,
      iterations: params.iterations,
      hashLength: params.hashLength,
    );
    final secretKey = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return secretKey.extractBytes();
  }
}
