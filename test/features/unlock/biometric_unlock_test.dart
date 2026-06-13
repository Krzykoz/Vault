import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/features/unlock/vault_controller.dart';

import '../../support/fakes.dart';

void main() {
  late InMemoryFileStore store;
  late InMemorySecureStore secureStore;
  late FakeBiometricGate gate;

  setUp(() {
    store = InMemoryFileStore();
    secureStore = InMemorySecureStore();
    gate = FakeBiometricGate(available: true, willSucceed: true);
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        vaultFileStoreProvider.overrideWithValue(store),
        vaultCreateParamsProvider
            .overrideWithValue(const Argon2Params.forTesting()),
        secureStoreProvider.overrideWithValue(secureStore),
        biometricGateProvider.overrideWithValue(gate),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  // Reads the controller until its initial async [_init] settles off loading.
  Future<VaultUiState> settled(ProviderContainer c) async {
    var state = c.read(vaultControllerProvider);
    for (var i = 0; i < 100 && state.phase == VaultPhase.loading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      state = c.read(vaultControllerProvider);
    }
    return state;
  }

  test('_init reports biometrics available but not yet enrolled', () async {
    final c = makeContainer();
    final state = await settled(c);
    expect(state.biometricAvailable, isTrue);
    expect(state.biometricEnrolled, isFalse);
  });

  test('enabling biometrics on create stores the password', () async {
    final c = makeContainer();
    await settled(c);

    await c
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame', enableBiometric: true);

    final state = c.read(vaultControllerProvider);
    expect(state.phase, VaultPhase.open);
    expect(secureStore.entries['vault_password'], 'opensesame');
    expect(gate.authCalls, 1);
  });

  test('creating without the flag leaves no stored credential', () async {
    final c = makeContainer();
    await settled(c);

    await c
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame');

    expect(secureStore.entries, isEmpty);
    expect(gate.authCalls, 0);
  });

  test('a returning user with a stored credential is shown as enrolled',
      () async {
    // First session: create the vault and enroll biometrics.
    final first = makeContainer();
    await settled(first);
    await first
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame', enableBiometric: true);

    // Second session reuses the same file + secure storage.
    final second = makeContainer();
    final state = await settled(second);
    expect(state.phase, VaultPhase.locked);
    expect(state.biometricAvailable, isTrue);
    expect(state.biometricEnrolled, isTrue);
  });

  test('unlockWithBiometrics opens the vault using the stored password',
      () async {
    final first = makeContainer();
    await settled(first);
    await first
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame', enableBiometric: true);

    final second = makeContainer();
    await settled(second);
    await second.read(vaultControllerProvider.notifier).unlockWithBiometrics();

    expect(second.read(vaultControllerProvider).phase, VaultPhase.open);
  });

  test('a cancelled biometric prompt keeps the vault locked and enrolled',
      () async {
    final first = makeContainer();
    await settled(first);
    await first
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame', enableBiometric: true);

    secureStore.failReads = true; // the OS prompt was cancelled/failed
    final second = makeContainer();
    await settled(second);
    await second.read(vaultControllerProvider.notifier).unlockWithBiometrics();

    final state = second.read(vaultControllerProvider);
    expect(state.phase, VaultPhase.locked);
    expect(state.error, contains('Biometric'));
    // The credential is still valid, so it is kept for a retry.
    expect(secureStore.entries.containsKey('vault_password'), isTrue);
    expect(state.biometricEnrolled, isTrue);
  });

  test('a stale saved password is discarded and falls back to password',
      () async {
    final first = makeContainer();
    await settled(first);
    await first
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame');

    // Simulate a credential that no longer matches the vault.
    secureStore.entries['vault_password'] = 'a-stale-password';

    final second = makeContainer();
    final initial = await settled(second);
    expect(initial.biometricEnrolled, isTrue);

    await second.read(vaultControllerProvider.notifier).unlockWithBiometrics();

    final state = second.read(vaultControllerProvider);
    expect(state.phase, VaultPhase.locked);
    expect(state.biometricEnrolled, isFalse);
    expect(secureStore.entries, isEmpty);
    expect(state.error, contains('password'));
  });

  test('a keychain write failure keeps the vault open but unenrolled', () async {
    secureStore.failWrites = true;
    final c = makeContainer();
    await settled(c);

    await c
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame', enableBiometric: true);

    final state = c.read(vaultControllerProvider);
    expect(state.phase, VaultPhase.open);
    expect(secureStore.entries, isEmpty);
  });

  test('creating a vault without opting in clears any leftover credential',
      () async {
    // A credential survives from a previous vault that no longer exists.
    secureStore.entries['vault_password'] = 'leftover';

    final c = makeContainer();
    await settled(c);
    await c
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame');

    expect(secureStore.entries, isEmpty);

    // A fresh launch must not treat the new vault as biometric-enrolled.
    final next = makeContainer();
    final state = await settled(next);
    expect(state.biometricEnrolled, isFalse);
  });

  test('declining the enrolment prompt does not store a credential', () async {
    gate.willSucceed = false;
    final c = makeContainer();
    await settled(c);

    await c
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame', enableBiometric: true);

    expect(c.read(vaultControllerProvider).phase, VaultPhase.open);
    expect(secureStore.entries, isEmpty);
  });

  test('biometrics unavailable: never enrolls and reports unavailable',
      () async {
    gate.available = false;
    final c = makeContainer();
    final state = await settled(c);
    expect(state.biometricAvailable, isFalse);

    await c
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame', enableBiometric: true);

    expect(secureStore.entries, isEmpty);
    expect(gate.authCalls, 0);
  });

  test('password unlock still works after biometrics are enrolled', () async {
    final first = makeContainer();
    await settled(first);
    await first
        .read(vaultControllerProvider.notifier)
        .create(password: 'opensesame', enableBiometric: true);

    final second = makeContainer();
    await settled(second);
    await second
        .read(vaultControllerProvider.notifier)
        .unlock(password: 'opensesame');

    expect(second.read(vaultControllerProvider).phase, VaultPhase.open);
  });
}
