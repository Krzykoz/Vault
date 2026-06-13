import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/model/payload.dart';
import 'package:vault/core/model/settings.dart';
import 'package:vault/core/providers/provider_registry.dart';
import 'package:vault/core/refresh/price_refresher.dart';
import 'package:vault/core/vault_repository.dart';
import 'package:vault/features/portfolio/portfolio_view.dart';
import 'package:vault/features/unlock/vault_controller.dart';

import '../../support/fakes.dart';

void main() {
  final usd = Currency('USD');
  final eur = Currency('EUR');

  test('refresh updates and persists the price cache', () async {
    final store = InMemoryFileStore();
    final market = FakeMarket(quotes: {'AAPL': Money.parse('150', usd)});
    final container = ProviderContainer(
      overrides: [
        vaultFileStoreProvider.overrideWithValue(store),
        vaultCreateParamsProvider
            .overrideWithValue(const Argon2Params.forTesting()),
        biometricGateProvider
            .overrideWithValue(FakeBiometricGate(available: false)),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
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
        id: 'a',
        type: AssetType.stock,
        name: 'Apple',
        nativeCurrency: usd,
        symbol: 'AAPL',
      ),
    );

    await controller.refresh();

    final cached = container
        .read(vaultControllerProvider)
        .payload!
        .priceCache
        .bySymbol('AAPL');
    expect(cached!.price, Money.parse('150', usd));

    // Persisted: a fresh repository sees the cached price too.
    final reopened = await VaultRepository(store).open(password: 'pw');
    expect(reopened.priceCache.bySymbol('AAPL')!.price, Money.parse('150', usd));
  });

  test('a foreign-currency asset becomes fully valued after a refresh', () async {
    final date = DateTime.utc(2023, 5, 1);
    final now = DateTime.utc(2024, 6, 1);
    final market = FakeMarket(
      quotes: {'SAP': Money.parse('120', eur)},
      latestRates: {'EURUSD': Decimal.parse('1.2')},
      datedRates: {'EURUSD@2023-05-01': Decimal.parse('1.1')},
    );
    final before = VaultPayload(
      settings: Settings(baseCurrency: usd),
      assets: [
        Asset(
          id: 's',
          type: AssetType.stock,
          name: 'SAP',
          nativeCurrency: eur,
          symbol: 'SAP',
        ),
      ],
      lots: [
        Lot(
          id: 'l',
          assetId: 's',
          quantity: Decimal.fromInt(2),
          unitCost: Money.parse('100', eur),
          date: date,
        ),
      ],
    );

    final result =
        await PriceRefresher(ProviderRegistry([market]), market).refresh(before, now: now);
    final after = before.copyWith(
      priceCache: result.priceCache,
      fxCache: result.fxCache,
    );

    final row = buildPortfolioView(after, now: now).rows.single;
    // value: 2 * 120 EUR = 240 EUR at latest 1.2 = 288 USD.
    expect(row.value, Money.parse('288', usd));
    // cost: 2 * 100 EUR = 200 EUR at purchase-date 1.1 = 220 USD.
    expect(row.costBasis, Money.parse('220', usd));
    expect(row.gain, Money.parse('68', usd));
  });
}
