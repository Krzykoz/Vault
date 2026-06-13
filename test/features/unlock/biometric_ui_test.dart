import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/features/unlock/vault_controller.dart';
import 'package:vault/main.dart';

import '../../support/fakes.dart';

Future<void> _pumpUntil(WidgetTester tester, Finder finder,
    {int tries = 100}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsWidgets);
}

void main() {
  late InMemoryFileStore store;
  late InMemorySecureStore secureStore;
  late FakeBiometricGate gate;

  setUp(() {
    store = InMemoryFileStore();
    secureStore = InMemorySecureStore();
    gate = FakeBiometricGate(available: true, willSucceed: true);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultFileStoreProvider.overrideWithValue(store),
          vaultCreateParamsProvider
              .overrideWithValue(const Argon2Params.forTesting()),
          secureStoreProvider.overrideWithValue(secureStore),
          biometricGateProvider.overrideWithValue(gate),
        ],
        child: const VaultApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('enroll on create, then unlock with the biometric button',
      (tester) async {
    await pumpApp(tester);

    await tester.enterText(find.byKey(const Key('password')), 'opensesame');
    await tester.enterText(find.byKey(const Key('confirm')), 'opensesame');
    await tester.tap(find.byKey(const Key('enable-biometric')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('create')));
    await _pumpUntil(tester, find.text('Portfolio'));

    expect(secureStore.entries['vault_password'], 'opensesame');

    await tester.tap(find.byKey(const Key('lock')));
    await tester.pumpAndSettle();

    final bioButton = find.byKey(const Key('unlock-biometric'));
    expect(bioButton, findsOneWidget);

    await tester.tap(bioButton);
    await _pumpUntil(tester, find.text('Portfolio'));
    expect(find.text('Portfolio'), findsOneWidget);
  });

  testWidgets('no biometric controls when the device has no biometrics',
      (tester) async {
    gate.available = false;
    await pumpApp(tester);
    expect(find.byKey(const Key('enable-biometric')), findsNothing);
  });
}
