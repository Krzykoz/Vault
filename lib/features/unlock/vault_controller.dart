import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/aead.dart';
import '../../core/crypto/kdf.dart';
import '../../core/model/currency.dart';
import '../../core/model/payload.dart';
import '../../core/model/settings.dart';
import '../../core/ports/file_store.dart';
import '../../core/vault_repository.dart';

/// Where the encrypted vault file lives. Overridden at app start with a native
/// path (or in tests with an in-memory store), so the default throws to catch
/// missing wiring early.
final vaultFileStoreProvider = Provider<FileStore>((ref) {
  throw UnimplementedError('vaultFileStoreProvider must be overridden');
});

/// Argon2id parameters used when creating a NEW vault. Overridden to a fast
/// preset in tests.
final vaultCreateParamsProvider =
    Provider<Argon2Params>((ref) => const Argon2Params());

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  return VaultRepository(
    ref.watch(vaultFileStoreProvider),
    createParams: ref.watch(vaultCreateParamsProvider),
  );
});

/// Which screen the vault flow should show.
enum VaultPhase { loading, absent, locked, open }

class VaultUiState {
  final VaultPhase phase;
  final bool busy;
  final String? error;
  final VaultPayload? payload;

  const VaultUiState({
    required this.phase,
    this.busy = false,
    this.error,
    this.payload,
  });
}

/// Drives create / unlock / lock and exposes which screen to show.
class VaultController extends Notifier<VaultUiState> {
  @override
  VaultUiState build() {
    _init();
    return const VaultUiState(phase: VaultPhase.loading);
  }

  VaultRepository get _repo => ref.read(vaultRepositoryProvider);

  Future<void> _init() async {
    final exists = await _repo.exists();
    state = VaultUiState(
      phase: exists ? VaultPhase.locked : VaultPhase.absent,
    );
  }

  Future<void> create({required String password}) async {
    state = const VaultUiState(phase: VaultPhase.absent, busy: true);
    try {
      final payload = await _repo.create(
        password: password,
        initial: VaultPayload(settings: Settings(baseCurrency: Currency('USD'))),
      );
      state = VaultUiState(phase: VaultPhase.open, payload: payload);
    } catch (_) {
      state = const VaultUiState(
        phase: VaultPhase.absent,
        error: 'Could not create the vault.',
      );
    }
  }

  Future<void> unlock({required String password}) async {
    state = const VaultUiState(phase: VaultPhase.locked, busy: true);
    try {
      final payload = await _repo.open(password: password);
      state = VaultUiState(phase: VaultPhase.open, payload: payload);
    } on WrongPassword {
      state = const VaultUiState(
        phase: VaultPhase.locked,
        error: 'Wrong password. Try again.',
      );
    } catch (_) {
      state = const VaultUiState(
        phase: VaultPhase.locked,
        error: 'Could not open the vault.',
      );
    }
  }

  void lock() {
    _repo.close();
    state = const VaultUiState(phase: VaultPhase.locked);
  }
}

final vaultControllerProvider =
    NotifierProvider<VaultController, VaultUiState>(VaultController.new);
