import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';

import '../model/payload.dart';
import 'aead.dart';
import 'kdf.dart';
import 'secure_random.dart';

/// Thrown when a byte stream is not a well-formed vault file (bad magic,
/// unsupported version, malformed CBOR, or missing fields). Distinct from
/// [WrongPassword], which means the file is valid but the password was wrong.
class InvalidVaultFile implements Exception {
  final String message;
  const InvalidVaultFile(this.message);

  @override
  String toString() => 'InvalidVaultFile: $message';
}

/// Reads and writes the on-disk vault format:
///
///   CBOR map { magic, version, kdf, salt, nonce, ct, mac }
///
/// where `ct` is the CBOR-encoded [VaultPayload] encrypted with AES-256-GCM
/// under an Argon2id key. The format is plain CBOR plus byte strings, so a file
/// written on one platform decodes identically on any other.
class VaultCodec {
  static const String magic = 'VLT1';
  static const int formatVersion = 1;
  static const int saltLength = 16;

  // Bounds for KDF parameters read from an untrusted file, so a malicious vault
  // cannot request absurd work and hang or crash the app before authentication.
  static const int _maxMemoryKib = 262144; // 256 MiB
  static const int _maxIterations = 64;
  static const int _maxParallelism = 64;
  static const int _requiredHashLength = 32; // AES-256 key length

  final Aead _aead;

  VaultCodec({Aead? aead}) : _aead = aead ?? Aead();

  /// Serializes and encrypts [payload] under [password]. A fresh random salt and
  /// nonce are used, so the same input yields different bytes each call.
  Future<Uint8List> encode({
    required VaultPayload payload,
    required String password,
    Argon2Params params = const Argon2Params(),
  }) async {
    final salt = secureRandomBytes(saltLength);
    final key = await Kdf(params).deriveKey(password: password, salt: salt);
    final plaintext = cborEncode(CborValue(payload.toMap()));
    final cipher =
        await _aead.encrypt(key: key, plaintext: plaintext, aad: _aad);

    final envelope = CborMap({
      CborString('magic'): CborString(magic),
      CborString('version'): CborSmallInt(formatVersion),
      CborString('kdf'): CborValue(params.toMap()),
      CborString('salt'): CborBytes(salt),
      CborString('nonce'): CborBytes(cipher.nonce),
      CborString('ct'): CborBytes(cipher.cipherText),
      CborString('mac'): CborBytes(cipher.mac),
    });
    return Uint8List.fromList(cborEncode(envelope));
  }

  /// Decrypts and deserializes a vault file. Throws [InvalidVaultFile] for a
  /// malformed file and [WrongPassword] for a valid file with the wrong
  /// password (or tampered ciphertext).
  Future<VaultPayload> decode({
    required List<int> bytes,
    required String password,
  }) async {
    final Map<Object?, Object?> envelope;
    try {
      final decoded = cborDecode(bytes).toObject();
      if (decoded is! Map) {
        throw const InvalidVaultFile('top-level value is not a map');
      }
      envelope = decoded;
    } on InvalidVaultFile {
      rethrow;
    } catch (_) {
      throw const InvalidVaultFile('not valid CBOR');
    }

    if (envelope['magic'] != magic) {
      throw InvalidVaultFile('bad magic: ${envelope['magic']}');
    }
    if (envelope['version'] != formatVersion) {
      throw InvalidVaultFile('unsupported version: ${envelope['version']}');
    }

    final params = _parseParams(envelope['kdf']);
    final salt = _asBytes(envelope['salt']);
    final cipher = CipherData(
      nonce: _asBytes(envelope['nonce']),
      cipherText: _asBytes(envelope['ct']),
      mac: _asBytes(envelope['mac']),
    );

    final key = await Kdf(params).deriveKey(password: password, salt: salt);
    final plaintext = await _aead.decrypt(key: key, data: cipher, aad: _aad);

    final Object? payload;
    try {
      payload = cborDecode(plaintext).toObject();
    } catch (_) {
      throw const InvalidVaultFile('decrypted payload is not valid CBOR');
    }
    if (payload is! Map) {
      throw const InvalidVaultFile('payload is not a map');
    }
    try {
      return VaultPayload.fromMap(payload.cast<String, dynamic>());
    } on InvalidVaultFile {
      rethrow;
    } catch (_) {
      throw const InvalidVaultFile('decrypted payload has an unexpected shape');
    }
  }

  /// Additional authenticated data binding the ciphertext to this format and
  /// version. Salt and KDF params are implicitly protected: altering them
  /// derives a different key, which fails the GCM authentication check.
  List<int> get _aad => utf8.encode('$magic.$formatVersion');

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) throw InvalidVaultFile('expected a map, got $value');
    return value.cast<String, dynamic>();
  }

  List<int> _asBytes(Object? value) {
    if (value is! List) throw InvalidVaultFile('expected bytes, got $value');
    final bytes = Uint8List(value.length);
    for (var i = 0; i < value.length; i++) {
      final byte = value[i];
      if (byte is! int || byte < 0 || byte > 255) {
        throw InvalidVaultFile('invalid byte at index $i: $byte');
      }
      bytes[i] = byte;
    }
    return bytes;
  }

  /// Parses and bounds-checks Argon2id parameters from an untrusted envelope.
  /// These are read before authentication can occur, so out-of-range values are
  /// rejected as [InvalidVaultFile] rather than handed to the KDF.
  Argon2Params _parseParams(Object? value) {
    final map = _asMap(value);
    final parallelism = _requireInt(map, 'parallelism');
    final memory = _requireInt(map, 'memory');
    final iterations = _requireInt(map, 'iterations');
    final hashLength = _requireInt(map, 'hashLength');

    if (parallelism < 1 || parallelism > _maxParallelism) {
      throw InvalidVaultFile('parallelism out of range: $parallelism');
    }
    if (memory < 8 * parallelism || memory > _maxMemoryKib) {
      throw InvalidVaultFile('memory out of range: $memory');
    }
    if (iterations < 1 || iterations > _maxIterations) {
      throw InvalidVaultFile('iterations out of range: $iterations');
    }
    if (hashLength != _requiredHashLength) {
      throw InvalidVaultFile('unsupported hashLength: $hashLength');
    }
    return Argon2Params(
      parallelism: parallelism,
      memory: memory,
      iterations: iterations,
      hashLength: hashLength,
    );
  }

  int _requireInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw InvalidVaultFile('field "$key" must be an int, got $value');
    }
    return value;
  }
}
