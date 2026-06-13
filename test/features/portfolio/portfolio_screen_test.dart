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

Future<void> _createVault(WidgetTester tester, InMemoryFileStore store) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vaultFileStoreProvider.overrideWithValue(store),
        vaultCreateParamsProvider
            .overrideWithValue(const Argon2Params.forTesting()),
      ],
      child: const VaultApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('password')), 'opensesame');
  await tester.enterText(find.byKey(const Key('confirm')), 'opensesame');
  await tester.tap(find.byKey(const Key('create')));
  await _pumpUntil(tester, find.text('Portfolio'));
}

void main() {
  testWidgets('add an asset through the UI; it lists and persists',
      (tester) async {
    final store = InMemoryFileStore();
    await _createVault(tester, store);
    expect(find.text('No assets yet. Add your first one.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-asset')));
    await tester.pumpAndSettle();
    expect(find.text('Add asset'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('name')), 'Apple');
    await tester.enterText(find.byKey(const Key('symbol')), 'AAPL');
    await tester.tap(find.byKey(const Key('save-asset')));

    await _pumpUntil(tester, find.text('Apple'));
    expect(find.text('Apple'), findsOneWidget);
    expect(store.bytes, isNotNull);
  });

  testWidgets('a missing name blocks saving the asset', (tester) async {
    final store = InMemoryFileStore();
    await _createVault(tester, store);

    await tester.tap(find.byKey(const Key('add-asset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-asset')));
    await tester.pump();

    expect(find.text('Required'), findsWidgets);
    expect(find.text('Add asset'), findsOneWidget); // still on the editor
  });

  testWidgets('priced assets offer a manual price fallback', (tester) async {
    final store = InMemoryFileStore();
    await _createVault(tester, store);

    await tester.tap(find.byKey(const Key('add-asset')));
    await tester.pumpAndSettle();

    // The default type is a stock (priced) — both symbol and manual price show.
    expect(find.byKey(const Key('symbol')), findsOneWidget);
    expect(find.byKey(const Key('manualPrice')), findsOneWidget);
  });
}
