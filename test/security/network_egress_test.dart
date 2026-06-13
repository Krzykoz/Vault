import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/model/payload.dart';
import 'package:vault/core/model/settings.dart';
import 'package:vault/core/providers/provider_registry.dart';
import 'package:vault/core/providers/yahoo_finance_provider.dart';
import 'package:vault/core/refresh/price_refresher.dart';

import '../support/fakes.dart';

/// Privacy invariant: the only thing that ever leaves the device is a price/FX
/// lookup to the configured provider. A refresh must never contact any other
/// host, and must always use TLS.
void main() {
  test('a refresh only ever contacts the configured Yahoo endpoint over https',
      () async {
    final http = FakeHttpClient(); // records every request; returns 404
    final yahoo = YahooFinanceProvider(http);
    final refresher = PriceRefresher(ProviderRegistry([yahoo]), yahoo);

    final usd = Currency('USD');
    final eur = Currency('EUR');
    final payload = VaultPayload(
      settings: Settings(baseCurrency: eur), // foreign asset forces an FX lookup
      assets: [
        Asset(
          id: 'a',
          type: AssetType.stock,
          name: 'Apple',
          nativeCurrency: usd,
          symbol: 'AAPL',
        ),
      ],
      lots: [
        Lot(
          id: 'l',
          assetId: 'a',
          quantity: Decimal.fromInt(2),
          unitCost: Money.parse('100', usd),
          date: DateTime.utc(2023, 5, 1),
        ),
      ],
    );

    await refresher.refresh(payload, now: DateTime.utc(2024, 6, 1));

    expect(http.requested, isNotEmpty);
    for (final uri in http.requested) {
      expect(uri.scheme, 'https', reason: 'non-TLS request to $uri');
      expect(uri.host, 'query1.finance.yahoo.com',
          reason: 'unexpected host contacted: $uri');
    }

    // Both a price lookup and an FX lookup must have gone out.
    expect(http.requested.any((u) => u.path.contains('AAPL')), isTrue,
        reason: 'expected a price lookup for AAPL');
    expect(http.requested.any((u) => u.path.contains('USDEUR')), isTrue,
        reason: 'expected an FX lookup for USD->EUR');
  });
}
