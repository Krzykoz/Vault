import 'package:cryptography/cryptography.dart';

/// The output of authenticated encryption: the random [nonce], the [cipherText],
/// and the authentication [mac]. All three are required to decrypt.
class CipherData {
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  const CipherData({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });
}

/// Thrown when decryption fails its authentication check. This means the
/// key/password was wrong or the ciphertext was tampered with — the two are
/// cryptographically indistinguishable.
class WrongPassword implements Exception {
  const WrongPassword();

  @override
  String toString() =>
      'WrongPassword: decryption failed (wrong password or corrupted data)';
}

/// AES-256-GCM authenticated encryption.
class Aead {
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Encrypts [plaintext] with a 256-bit [key]. A fresh random nonce is used on
  /// every call. [aad] is authenticated but not encrypted.
  Future<CipherData> encrypt({
    required List<int> key,
    required List<int> plaintext,
    List<int> aad = const [],
  }) async {
    final box = await _algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      aad: aad,
    );
    return CipherData(
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  /// Decrypts [data] with [key], throwing [WrongPassword] if authentication
  /// fails. [aad] must match what was supplied during encryption.
  Future<List<int>> decrypt({
    required List<int> key,
    required CipherData data,
    List<int> aad = const [],
  }) async {
    final box = SecretBox(
      data.cipherText,
      nonce: data.nonce,
      mac: Mac(data.mac),
    );
    try {
      return await _algorithm.decrypt(box, secretKey: SecretKey(key), aad: aad);
    } on SecretBoxAuthenticationError {
      throw const WrongPassword();
    }
  }
}
