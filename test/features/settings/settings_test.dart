import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/providers/provider_registry.dart';
import 'package:vault/core/refresh/price_refresher.dart';
import 'package:vault/features/portfolio/portfolio_view.dart';
import 'package:vault/features/settings/settings_screen.dart';
import 'package:vault/features/unlock/vault_controller.dart';

import '../../support/fakes.dart';

void main() {
  final eur = Currency('EUR');
  final gbp = Currency('GBP');
  final fixedNow = DateTime.utc(2024, 6, 1);
  final lotDate = DateTime.utc(2023, 5, 1);

  test('changing the base currency refetches FX and revalues', () async {
    final store = InMemoryFileStore();
    final market = FakeMarket(
      quotes: {'SAP': Money.parse('120', eur)},
      latestRates: {'EURGBP': Decimal.parse('0.85')},
      datedRates: {'EURGBP@2023-05-01': Decimal.parse('0.80')},
    );
    final container = ProviderContainer(
      overrides: [
        vaultFileStoreProvider.overrideWithValue(store),
        vaultCreateParamsProvider
            .overrideWithValue(const Argon2Params.forTesting()),
        biometricGateProvider
            .overrideWithValue(FakeBiometricGate(available: false)),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        clockProvider.overrideWithValue(FixedClock(fixedNow)),
        priceRefresherProvider.overrideWithValue(
          PriceRefresher(ProviderRegistry([market]), market),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(vaultControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await controller.create(password: 'pw');
    await controller.upsertAsset(
      Asset(
        id: 's',
        type: AssetType.stock,
        name: 'SAP',
        nativeCurrency: eur,
        symbol: 'SAP',
      ),
    );
    await controller.upsertLot(
      Lot(
        id: 'l',
        assetId: 's',
        quantity: Decimal.fromInt(2),
        unitCost: Money.parse('100', eur),
        date: lotDate,
      ),
    );

    await controller.setBaseCurrency(gbp);

    final payload = container.read(vaultControllerProvider).payload!;
    expect(payload.settings.baseCurrency, gbp);

    final row = buildPortfolioView(payload, now: fixedNow).rows.single;
    expect(row.value, Money.parse('204', gbp)); // 2*120 EUR * 0.85
    expect(row.costBasis, Money.parse('160', gbp)); // 2*100 EUR * 0.80
  });

  testWidgets('settings screen shows the current base currency', (tester) async {
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
    await tester.runAsync(() async {
      final controller = container.read(vaultControllerProvider.notifier);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await controller.create(password: 'pw'); // defaults to USD
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('base-currency')), findsOneWidget);
    expect(find.text('USD'), findsWidgets);
  });
}
