import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/features/unlock/vault_controller.dart';
import 'package:vault/main.dart';

import '../../support/fakes.dart';

/// Pumps frames (yielding to the event loop) until [finder] matches or we give
/// up — needed because create/unlock await real key derivation.
Future<void> _pumpUntil(WidgetTester tester, Finder finder,
    {int tries = 100}) async {
  for (var i = 0; i < tries; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(finder, findsWidgets);
}

void main() {
  Future<void> pumpApp(WidgetTester tester, InMemoryFileStore store) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultFileStoreProvider.overrideWithValue(store),
          vaultCreateParamsProvider
              .overrideWithValue(const Argon2Params.forTesting()),
          biometricGateProvider
              .overrideWithValue(FakeBiometricGate(available: false)),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        ],
        child: const VaultApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a new vault shows the create screen', (tester) async {
    await pumpApp(tester, InMemoryFileStore());
    expect(find.text('Create your vault'), findsOneWidget);
  });

  testWidgets('create, lock, then unlock a vault', (tester) async {
    final store = InMemoryFileStore();
    await pumpApp(tester, store);

    await tester.enterText(find.byKey(const Key('password')), 'opensesame');
    await tester.enterText(find.byKey(const Key('confirm')), 'opensesame');
    await tester.tap(find.byKey(const Key('create')));
    await _pumpUntil(tester, find.text('Portfolio'));
    expect(find.text('Portfolio'), findsOneWidget);

    // The file now exists on disk.
    expect(store.bytes, isNotNull);

    await tester.tap(find.byKey(const Key('lock')));
    await tester.pumpAndSettle();
    expect(find.text('Unlock your vault'), findsOneWidget);

    // Wrong password is rejected.
    await tester.enterText(find.byKey(const Key('password')), 'nope');
    await tester.tap(find.byKey(const Key('unlock')));
    await _pumpUntil(tester, find.textContaining('Wrong password'));
    expect(find.textContaining('Wrong password'), findsOneWidget);

    // Correct password opens it.
    await tester.enterText(find.byKey(const Key('password')), 'opensesame');
    await tester.tap(find.byKey(const Key('unlock')));
    await _pumpUntil(tester, find.text('Portfolio'));
    expect(find.text('Portfolio'), findsOneWidget);
  });

  testWidgets('rejects a too-short password', (tester) async {
    await pumpApp(tester, InMemoryFileStore());
    await tester.enterText(find.byKey(const Key('password')), 'short');
    await tester.enterText(find.byKey(const Key('confirm')), 'short');
    await tester.tap(find.byKey(const Key('create')));
    await tester.pump();
    expect(find.text('Use at least 8 characters'), findsOneWidget);
    expect(find.text('Create your vault'), findsOneWidget); // still here
  });

  testWidgets('rejects mismatched passwords', (tester) async {
    await pumpApp(tester, InMemoryFileStore());
    await tester.enterText(find.byKey(const Key('password')), 'longenough');
    await tester.enterText(find.byKey(const Key('confirm')), 'different1');
    await tester.tap(find.byKey(const Key('create')));
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
