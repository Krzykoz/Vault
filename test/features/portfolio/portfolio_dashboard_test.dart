import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/features/portfolio/portfolio_screen.dart';
import 'package:vault/features/unlock/vault_controller.dart';

import '../../support/fakes.dart';

void main() {
  final usd = Currency('USD');

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        vaultFileStoreProvider.overrideWithValue(InMemoryFileStore()),
        vaultCreateParamsProvider
            .overrideWithValue(const Argon2Params.forTesting()),
        biometricGateProvider
            .overrideWithValue(FakeBiometricGate(available: false)),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> render(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PortfolioScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the total value and a holding row', (tester) async {
    final container = makeContainer();
    await tester.runAsync(() async {
      final controller = container.read(vaultControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.create(password: 'pw');
      await controller.upsertAsset(
        Asset(
          id: 'gold',
          type: AssetType.manual,
          name: 'Gold',
          nativeCurrency: usd,
          manualPrice: Money.parse('2000', usd),
        ),
      );
      await controller.upsertLot(
        Lot(
          id: 'l',
          assetId: 'gold',
          quantity: Decimal.fromInt(2),
          unitCost: Money.parse('1500', usd),
          date: DateTime.utc(2023, 1, 1),
        ),
      );
    });

    await render(tester, container);

    expect(find.text('Gold'), findsOneWidget);
    expect(find.byKey(const Key('total-value')), findsOneWidget);
    expect(find.textContaining('4000'), findsWidgets);
  });

  testWidgets('shows the empty state with no assets', (tester) async {
    final container = makeContainer();
    await tester.runAsync(() async {
      final controller = container.read(vaultControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.create(password: 'pw');
    });

    await render(tester, container);
    expect(find.text('No assets yet. Add your first one.'), findsOneWidget);
  });
}
