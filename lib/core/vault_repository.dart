import 'crypto/kdf.dart';
import 'crypto/vault_file.dart';
import 'model/payload.dart';
import 'ports/file_store.dart';

/// Thrown by [VaultRepository.open] when no vault file exists yet.
class VaultNotFound implements Exception {
  const VaultNotFound();

  @override
  String toString() => 'VaultNotFound: no vault file present';
}

/// Owns the decrypted in-memory session and persists it through a [FileStore].
///
/// After [create] or [open], the derived Argon2id key is cached, so every
/// [save] only re-runs AES-GCM (with a fresh nonce) instead of the expensive key
/// derivation. The decrypted payload never leaves memory except as ciphertext.
class VaultRepository {
  final FileStore _fileStore;
  final VaultCodec _codec;
  final Argon2Params _createParams;

  List<int>? _key;
  List<int>? _salt;
  Argon2Params? _params;
  VaultPayload? _payload;

  VaultRepository(
    this._fileStore, {
    VaultCodec? codec,
    Argon2Params createParams = const Argon2Params(),
  })  : _codec = codec ?? VaultCodec(),
        _createParams = createParams;

  /// Whether a vault has been opened/created in this session.
  bool get isOpen => _payload != null;

  /// The current decrypted payload. Throws [StateError] if the vault isn't open.
  VaultPayload get payload {
    final current = _payload;
    if (current == null) throw StateError('Vault is not open');
    return current;
  }

  /// Whether a vault file already exists in the backing store.
  Future<bool> exists() async => (await _fileStore.read()) != null;

  /// Creates a new vault from [initial], encrypts it under [password], and
  /// writes it. The session is left open.
  Future<VaultPayload> create({
    required String password,
    required VaultPayload initial,
  }) async {
    final session = await _codec.encodeNew(
      payload: initial,
      password: password,
      params: _createParams,
    );
    await _fileStore.write(session.bytes);
    _key = session.key;
    _salt = session.salt;
    _params = session.params;
    _payload = initial;
    return initial;
  }

  /// Opens and decrypts the existing vault with [password]. Throws
  /// [VaultNotFound] if there is no file, [WrongPassword] on a bad password, or
  /// [InvalidVaultFile] on a malformed file.
  Future<VaultPayload> open({required String password}) async {
    final bytes = await _fileStore.read();
    if (bytes == null) throw const VaultNotFound();
    final session = await _codec.decodeSession(bytes: bytes, password: password);
    _key = session.key;
    _salt = session.salt;
    _params = session.params;
    _payload = session.payload;
    return session.payload;
  }

  /// Persists [next] using the cached key (no Argon2id) and updates the session.
  Future<VaultPayload> save(VaultPayload next) async {
    final key = _key;
    final salt = _salt;
    final params = _params;
    if (key == null || salt == null || params == null) {
      throw StateError('Vault is not open');
    }
    final bytes = await _codec.encodeWithKey(
      payload: next,
      key: key,
      salt: salt,
      params: params,
    );
    await _fileStore.write(bytes);
    _payload = next;
    return next;
  }

  /// Applies [change] to the current payload and saves the result.
  Future<VaultPayload> update(VaultPayload Function(VaultPayload current) change) =>
      save(change(payload));

  /// Clears the in-memory session (key and payload).
  void close() {
    _key = null;
    _salt = null;
    _params = null;
    _payload = null;
  }
}
