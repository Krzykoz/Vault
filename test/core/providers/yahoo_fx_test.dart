import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/cache/fx_cache.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/ports/http_client.dart';
import 'package:vault/core/providers/price_provider.dart';
import 'package:vault/core/providers/yahoo_finance_provider.dart';

import '../../support/fakes.dart';

const _latestBody =
    '{"chart":{"result":[{"meta":{"currency":"USD","symbol":"EURUSD=X",'
    '"regularMarketPrice":1.1023,"regularMarketTime":1700000000}}],"error":null}}';

const _historicalBody =
    '{"chart":{"result":[{"meta":{"currency":"USD","symbol":"EURUSD=X"},'
    '"timestamp":[1682899200],"indicators":{"quote":[{"close":[1.0950]}]}}],'
    '"error":null}}';

void main() {
  final eur = Currency('EUR');
  final usd = Currency('USD');

  test('fetches the latest spot rate', () async {
    final url = YahooFinanceProvider.fxUrl(eur, usd).toString();
    final http = FakeHttpClient({url: const HttpResponse(200, _latestBody)});
    final quote = await YahooFinanceProvider(http).fetchRate(eur, usd);
    expect(quote.rate, Decimal.parse('1.1023'));
    expect(quote.date, isNull);
    expect(
      quote.asOf,
      DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
    );
  });

  test('fetches a historical rate for a specific day', () async {
    final date = DateTime.utc(2023, 5, 1);
    final url = YahooFinanceProvider.fxUrl(eur, usd, date: date).toString();
    final http = FakeHttpClient({url: const HttpResponse(200, _historicalBody)});
    final quote = await YahooFinanceProvider(http).fetchRate(eur, usd, date: date);
    expect(quote.rate, Decimal.parse('1.0950'));
    expect(quote.date, date);
  });

  test('a same-currency rate is 1 and makes no request', () async {
    final http = FakeHttpClient();
    final quote = await YahooFinanceProvider(http).fetchRate(usd, usd);
    expect(quote.rate, Decimal.fromInt(1));
    expect(http.requested, isEmpty);
  });

  test('a failed request throws PriceUnavailable', () async {
    expect(
      () => YahooFinanceProvider(FakeHttpClient()).fetchRate(eur, usd),
      throwsA(isA<PriceUnavailable>()),
    );
  });

  test('a latest rate without a timestamp throws PriceUnavailable', () async {
    const body =
        '{"chart":{"result":[{"meta":{"currency":"USD","symbol":"EURUSD=X",'
        '"regularMarketPrice":1.1023}}],"error":null}}';
    final url = YahooFinanceProvider.fxUrl(eur, usd).toString();
    final http = FakeHttpClient({url: const HttpResponse(200, body)});
    expect(
      () => YahooFinanceProvider(http).fetchRate(eur, usd),
      throwsA(isA<PriceUnavailable>()),
    );
  });

  test('a latest rate round-trips through the cache', () async {
    final url = YahooFinanceProvider.fxUrl(eur, usd).toString();
    final http = FakeHttpClient({url: const HttpResponse(200, _latestBody)});
    final quote = await YahooFinanceProvider(http).fetchRate(eur, usd);
    final cache = FxCache().put(FxRateEntry(
      base: eur,
      quote: usd,
      rate: quote.rate,
      fetchedAt: quote.asOf,
      date: quote.date,
    ));
    expect(
      cache
          .freshLatest(eur, usd,
              ttl: const Duration(hours: 12), now: quote.asOf)!
          .rate,
      Decimal.parse('1.1023'),
    );
  });

  test('a historical rate caches under its calendar day', () async {
    final date = DateTime.utc(2023, 5, 1);
    final url = YahooFinanceProvider.fxUrl(eur, usd, date: date).toString();
    final http = FakeHttpClient({url: const HttpResponse(200, _historicalBody)});
    final quote = await YahooFinanceProvider(http).fetchRate(eur, usd, date: date);
    final cache = FxCache().put(FxRateEntry(
      base: eur,
      quote: usd,
      rate: quote.rate,
      fetchedAt: DateTime.utc(2024, 1, 1),
      date: quote.date,
    ));
    expect(cache.dated(eur, usd, date)!.rate, Decimal.parse('1.0950'));
  });
}
