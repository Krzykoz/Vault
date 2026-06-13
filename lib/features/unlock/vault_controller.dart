import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/aead.dart';
import '../../core/crypto/kdf.dart';
import '../../core/model/asset.dart';
import '../../core/model/currency.dart';
import '../../core/model/lot.dart';
import '../../core/model/payload.dart';
import '../../core/model/settings.dart';
import '../../core/ports/biometric_gate.dart';
import '../../core/ports/clock.dart';
import '../../core/ports/file_store.dart';
import '../../core/ports/http_client.dart';
import '../../core/ports/secure_store.dart';
import '../../core/providers/provider_registry.dart';
import '../../core/providers/yahoo_finance_provider.dart';
import '../../core/refresh/price_refresher.dart';
import '../../core/vault_repository.dart';
import '../../infra/biometric_gate_impl.dart';
import '../../infra/http_client_impl.dart';
import '../../infra/secure_store_impl.dart';
import '../../infra/system_clock.dart';

/// Where the encrypted vault file lives. Overridden at app start with a native
/// path (or in tests with an in-memory store), so the default throws to catch
/// missing wiring early.
final vaultFileStoreProvider = Provider<FileStore>((ref) {
  throw UnimplementedError('vaultFileStoreProvider must be overridden');
});

/// The clock used for cache-freshness decisions. Overridden in tests.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// HTTP client used by the price providers. Overridden in tests.
final httpClientProvider = Provider<HttpClient>((ref) => HttpClientImpl());

/// Refreshes prices and FX using Yahoo. Overridden in tests with fakes.
final priceRefresherProvider = Provider<PriceRefresher>((ref) {
  final yahoo = YahooFinanceProvider(ref.watch(httpClientProvider));
  return PriceRefresher(ProviderRegistry([yahoo]), yahoo);
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

/// Biometric authentication. Overridden in tests with a fake.
final biometricGateProvider =
    Provider<BiometricGate>((ref) => BiometricGateImpl());

/// Secure storage for the biometric-unlock password. Overridden in tests.
final secureStoreProvider = Provider<SecureStore>((ref) => SecureStoreImpl());

/// Which screen the vault flow should show.
enum VaultPhase { loading, absent, locked, open }

class VaultUiState {
  final VaultPhase phase;
  final bool busy;
  final String? error;
  final VaultPayload? payload;
  final bool refreshing;
  final String? note;
  final bool biometricAvailable;
  final bool biometricEnrolled;

  const VaultUiState({
    required this.phase,
    this.busy = false,
    this.error,
    this.payload,
    this.refreshing = false,
    this.note,
    this.biometricAvailable = false,
    this.biometricEnrolled = false,
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

  /// Bumped whenever the session changes (open/lock). A mutation captures the
  /// epoch before its async write and drops its result if the epoch moved,
  /// so a write completing after [lock] cannot reopen the vault.
  int _epoch = 0;

  bool _bioAvailable = false;
  bool _bioEnrolled = false;
  static const String _biometricKey = 'vault_password';

  VaultUiState _gateState(VaultPhase phase, {bool busy = false, String? error}) {
    return VaultUiState(
      phase: phase,
      busy: busy,
      error: error,
      biometricAvailable: _bioAvailable,
      biometricEnrolled: _bioEnrolled,
    );
  }

  Future<void> _init() async {
    final exists = await _repo.exists();
    _bioAvailable = await _probeBiometricsAvailable();
    if (!exists) {
      // A leftover credential must not auto-enroll a vault that no longer
      // exists, nor a fresh one the user creates later.
      await _clearBiometric();
    }
    _bioEnrolled = exists && await _hasStoredCredential();
    state = _gateState(exists ? VaultPhase.locked : VaultPhase.absent);
  }

  /// Biometric and secure-storage support varies by platform and can throw
  /// (e.g. web, or a desktop without a keychain). Treat any failure as
  /// "unavailable" so the app still falls back to password unlock.
  Future<bool> _probeBiometricsAvailable() async {
    try {
      return await ref.read(biometricGateProvider).isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasStoredCredential() async {
    try {
      return await ref.read(secureStoreProvider).containsKey(_biometricKey);
    } catch (_) {
      return false;
    }
  }

  Future<void> create({
    required String password,
    bool enableBiometric = false,
  }) async {
    state = _gateState(VaultPhase.absent, busy: true);
    try {
      final payload = await _repo.create(
        password: password,
        initial: VaultPayload(settings: Settings(baseCurrency: Currency('USD'))),
      );
      // A brand-new vault must only be biometric-enrolled if the user opts in
      // here; otherwise clear any credential left over from a previous vault.
      if (enableBiometric) {
        await _enableBiometric(password);
      } else {
        await _clearBiometric();
      }
      _epoch++;
      state = VaultUiState(phase: VaultPhase.open, payload: payload);
    } catch (_) {
      state = _gateState(VaultPhase.absent, error: 'Could not create the vault.');
    }
  }

  Future<void> unlock({
    required String password,
    bool enableBiometric = false,
  }) async {
    state = _gateState(VaultPhase.locked, busy: true);
    try {
      final payload = await _repo.open(password: password);
      if (enableBiometric) await _enableBiometric(password);
      _epoch++;
      state = VaultUiState(phase: VaultPhase.open, payload: payload);
    } on WrongPassword {
      state = _gateState(VaultPhase.locked, error: 'Wrong password. Try again.');
    } catch (_) {
      state = _gateState(VaultPhase.locked, error: 'Could not open the vault.');
    }
  }

  /// Reads the biometric-bound password (which makes the OS prompt for a
  /// fingerprint / face) and unlocks with it. If the saved password no longer
  /// opens this vault, it is discarded so the user can re-enroll.
  Future<void> unlockWithBiometrics() async {
    if (!_bioEnrolled) return;
    final String? password;
    try {
      password = await ref.read(secureStoreProvider).read(_biometricKey);
    } catch (_) {
      // The OS prompt was cancelled or failed. The saved password is still
      // valid, so keep it and let the user retry or type their password.
      state = _gateState(
        VaultPhase.locked,
        error: 'Biometric authentication failed.',
      );
      return;
    }
    if (password == null) {
      await _clearBiometric();
      state = _gateState(
        VaultPhase.locked,
        error: 'Saved credentials are no longer available. Enter your password.',
      );
      return;
    }
    await unlock(password: password);
    if (state.phase != VaultPhase.open) {
      // The saved password didn't open this vault (e.g. the file was replaced).
      // Drop it and fall back to password entry so the user can re-enroll.
      await _clearBiometric();
      state = _gateState(
        VaultPhase.locked,
        error: 'Saved credentials no longer match this vault. Enter your password.',
      );
    }
  }

  /// Confirms the user with a biometric prompt, then saves the password in the
  /// biometric-bound secure store. Best-effort: a storage failure leaves the
  /// vault open with biometrics simply not enabled.
  Future<void> _enableBiometric(String password) async {
    if (!_bioAvailable) return;
    if (!await _promptBiometrics('Enable biometric unlock')) return;
    try {
      await ref.read(secureStoreProvider).write(_biometricKey, password);
      _bioEnrolled = true;
    } catch (_) {
      // Saving to the keychain failed; leave biometrics off but keep the vault
      // open so the create/unlock the user asked for still succeeds.
    }
  }

  Future<void> _clearBiometric() async {
    _bioEnrolled = false;
    try {
      await ref.read(secureStoreProvider).delete(_biometricKey);
    } catch (_) {
      // Best effort: nothing else to do if the keychain delete fails.
    }
  }

  /// Runs the biometric prompt, mapping a thrown platform error to a plain
  /// "not authenticated" so callers never see an unhandled exception.
  Future<bool> _promptBiometrics(String reason) async {
    try {
      return await ref.read(biometricGateProvider).authenticate(reason: reason);
    } catch (_) {
      return false;
    }
  }

  void lock() {
    _epoch++;
    _repo.close();
    state = _gateState(VaultPhase.locked);
  }

  /// Web: lets the user pick an existing vault file to open. On platforms whose
  /// store has no picker this is a no-op.
  Future<void> openExistingFile() async {
    final store = ref.read(vaultFileStoreProvider);
    if (store is FilePicker) {
      if (await store.pickInto()) {
        state = const VaultUiState(phase: VaultPhase.locked);
      }
    }
  }

  /// Fetches fresh prices and FX for the held assets, persists the updated
  /// caches, and notes any failures. Safe to call only while open.
  Future<void> refresh() async {
    final current = state.payload;
    if (current == null) return;
    final epoch = _epoch;
    state = VaultUiState(
      phase: VaultPhase.open,
      payload: current,
      refreshing: true,
    );
    try {
      final result = await ref
          .read(priceRefresherProvider)
          .refresh(current, now: ref.read(clockProvider).now());
      if (epoch != _epoch) return;
      final next = await _repo.update((payload) => payload.copyWith(
            priceCache: result.priceCache,
            fxCache: result.fxCache,
          ));
      if (epoch != _epoch) return;
      state = VaultUiState(
        phase: VaultPhase.open,
        payload: next,
        note: result.hadFailures
            ? 'Some prices could not be updated. Set a manual price if needed.'
            : null,
      );
    } catch (_) {
      if (epoch != _epoch) return;
      state = VaultUiState(
        phase: VaultPhase.open,
        payload: current,
        note: 'Could not refresh prices.',
      );
    }
  }

  /// Adds [asset] if its id is new, or replaces the existing one.
  Future<void> upsertAsset(Asset asset) => _mutate((payload) {
        final assets = [...payload.assets];
        final index = assets.indexWhere((a) => a.id == asset.id);
        if (index >= 0) {
          assets[index] = asset;
        } else {
          assets.add(asset);
        }
        return payload.copyWith(assets: assets);
      });

  /// Removes an asset and any lots that belonged to it.
  Future<void> deleteAsset(String assetId) => _mutate((payload) => payload.copyWith(
        assets: payload.assets.where((a) => a.id != assetId).toList(),
        lots: payload.lots.where((l) => l.assetId != assetId).toList(),
      ));

  /// Adds [lot] if its id is new, or replaces the existing one.
  Future<void> upsertLot(Lot lot) => _mutate((payload) {
        final lots = [...payload.lots];
        final index = lots.indexWhere((l) => l.id == lot.id);
        if (index >= 0) {
          lots[index] = lot;
        } else {
          lots.add(lot);
        }
        return payload.copyWith(lots: lots);
      });

  Future<void> deleteLot(String lotId) => _mutate(
        (payload) => payload.copyWith(
          lots: payload.lots.where((l) => l.id != lotId).toList(),
        ),
      );

  /// Changes the base/display currency, then refetches the FX rates the new base
  /// needs so totals and gain/loss update.
  Future<void> setBaseCurrency(Currency base) async {
    final current = state.payload;
    if (current == null || current.settings.baseCurrency == base) return;
    await _mutate(
      (payload) =>
          payload.copyWith(settings: payload.settings.copyWith(baseCurrency: base)),
    );
    await refresh();
  }

  Future<void> _mutate(VaultPayload Function(VaultPayload current) change) async {
    final epoch = _epoch;
    try {
      final next = await _repo.update(change);
      if (epoch != _epoch) return; // locked or reopened mid-write; drop the result
      state = VaultUiState(phase: VaultPhase.open, payload: next);
    } on StateError {
      // The vault was locked before the write started; nothing to update.
    }
  }
}

final vaultControllerProvider =
    NotifierProvider<VaultController, VaultUiState>(VaultController.new);
