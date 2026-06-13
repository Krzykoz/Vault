import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/model/payload.dart';
import 'package:vault/core/model/settings.dart';
import 'package:vault/core/providers/provider_registry.dart';
import 'package:vault/core/refresh/price_refresher.dart';

import '../../support/fakes.dart';

void main() {
  final usd = Currency('USD');
  final eur = Currency('EUR');
  final now = DateTime.utc(2024, 6, 1);

  PriceRefresher refresherWith(FakeMarket market) =>
      PriceRefresher(ProviderRegistry([market]), market);

  Asset stock(String id, String symbol, Currency currency) => Asset(
        id: id,
        type: AssetType.stock,
        name: symbol,
        nativeCurrency: currency,
        symbol: symbol,
      );

  test('fetches a quote for a priced asset and caches it', () async {
    final payload = VaultPayload(
      settings: Settings(baseCurrency: usd),
      assets: [stock('a', 'AAPL', usd)],
      lots: [
        Lot(
          id: 'l',
          assetId: 'a',
          quantity: Decimal.fromInt(1),
          unitCost: Money.parse('100', usd),
          date: DateTime.utc(2023, 1, 1),
        ),
      ],
    );
    final market = FakeMarket(quotes: {'AAPL': Money.parse('150', usd)});
    final result = await refresherWith(market).refresh(payload, now: now);
    expect(result.hadFailures, isFalse);
    expect(result.priceCache.bySymbol('AAPL')!.price, Money.parse('150', usd));
  });

  test('skips assets that have a manual price', () async {
    final payload = VaultPayload(
      settings: Settings(baseCurrency: usd),
      assets: [
        Asset(
          id: 'g',
          type: AssetType.manual,
          name: 'Gold',
          nativeCurrency: usd,
          manualPrice: Money.parse('2000', usd),
        ),
      ],
    );
    final result = await refresherWith(FakeMarket()).refresh(payload, now: now);
    expect(result.hadFailures, isFalse);
    expect(result.priceCache.length, 0);
  });

  test('fetches latest and historical FX for a foreign asset', () async {
    final date = DateTime.utc(2023, 5, 1);
    final payload = VaultPayload(
      settings: Settings(baseCurrency: usd),
      assets: [stock('s', 'SAP', eur)],
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
    final market = FakeMarket(
      quotes: {'SAP': Money.parse('120', eur)},
      latestRates: {'EURUSD': Decimal.parse('1.2')},
      datedRates: {'EURUSD@2023-05-01': Decimal.parse('1.1')},
    );
    final result = await refresherWith(market).refresh(payload, now: now);
    expect(result.hadFailures, isFalse);
    expect(result.priceCache.bySymbol('SAP')!.price, Money.parse('120', eur));
    expect(result.fxCache.latest(eur, usd)!.rate, Decimal.parse('1.2'));
    expect(result.fxCache.dated(eur, usd, date)!.rate, Decimal.parse('1.1'));
  });

  test('collects failures and still updates what it can', () async {
    final payload = VaultPayload(
      settings: Settings(baseCurrency: usd),
      assets: [stock('a', 'AAPL', usd), stock('b', 'BAD', usd)],
    );
    final market = FakeMarket(
      quotes: {'AAPL': Money.parse('150', usd)},
      failSymbols: {'BAD'},
    );
    final result = await refresherWith(market).refresh(payload, now: now);
    expect(result.hadFailures, isTrue);
    expect(result.failures, contains('BAD'));
    expect(result.priceCache.bySymbol('AAPL')!.price, Money.parse('150', usd));
  });
}
