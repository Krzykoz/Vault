import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/ports/http_client.dart';
import 'package:vault/core/providers/price_provider.dart';
import 'package:vault/core/providers/yahoo_finance_provider.dart';

import '../../support/fakes.dart';

/// An HttpClient whose every request fails, to exercise the network-error path.
class _ThrowingHttp implements HttpClient {
  @override
  Future<HttpResponse> get(Uri url, {Map<String, String>? headers}) async =>
      throw Exception('network down');
}

const _aaplUrl =
    'https://query1.finance.yahoo.com/v8/finance/chart/AAPL?interval=1d&range=1d';

String _chartBody(String price, {String currency = 'USD', int time = 1700000000}) =>
    '{"chart":{"result":[{"meta":{"currency":"$currency",'
    '"symbol":"AAPL","regularMarketPrice":$price,'
    '"regularMarketTime":$time}}],"error":null}}';

void main() {
  final usd = Currency('USD');

  Asset asset(AssetType type, {String? symbol}) => Asset(
        id: 'a',
        type: type,
        name: 'X',
        nativeCurrency: usd,
        symbol: symbol,
      );

  group('YahooFinanceProvider.supports', () {
    final provider = YahooFinanceProvider(FakeHttpClient());

    test('supports priced types that have a symbol', () {
      expect(provider.supports(asset(AssetType.stock, symbol: 'AAPL')), isTrue);
      expect(provider.supports(asset(AssetType.etf, symbol: 'VOO')), isTrue);
      expect(provider.supports(asset(AssetType.crypto, symbol: 'BTC-USD')), isTrue);
      expect(provider.supports(asset(AssetType.commodity, symbol: 'GC=F')), isTrue);
    });

    test('rejects cash, manual, and symbol-less assets', () {
      expect(provider.supports(asset(AssetType.cash)), isFalse);
      expect(provider.supports(asset(AssetType.manual)), isFalse);
      expect(provider.supports(asset(AssetType.stock)), isFalse);
    });
  });

  group('YahooFinanceProvider.fetchQuote', () {
    test('parses price, currency, and timestamp', () async {
      final http = FakeHttpClient({_aaplUrl: HttpResponse(200, _chartBody('190.25'))});
      final quote = await YahooFinanceProvider(http).fetchQuote('AAPL');
      expect(quote.price, Money.parse('190.25', usd));
      expect(
        quote.asOf,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
    });

    test('keeps full precision (never parses the price through a double)',
        () async {
      const precise = '123456789.123456789';
      final http = FakeHttpClient({_aaplUrl: HttpResponse(200, _chartBody(precise))});
      final quote = await YahooFinanceProvider(http).fetchQuote('AAPL');
      expect(quote.price, Money.parse(precise, usd));
    });

    test('a Yahoo error payload throws PriceUnavailable', () async {
      const body =
          '{"chart":{"result":null,"error":{"code":"Not Found","description":"x"}}}';
      final http = FakeHttpClient({_aaplUrl: const HttpResponse(200, body)});
      expect(
        () => YahooFinanceProvider(http).fetchQuote('AAPL'),
        throwsA(isA<PriceUnavailable>()),
      );
    });

    test('a non-2xx response throws PriceUnavailable', () async {
      // Unknown URL -> FakeHttpClient returns 404.
      expect(
        () => YahooFinanceProvider(FakeHttpClient()).fetchQuote('NOPE'),
        throwsA(isA<PriceUnavailable>()),
      );
    });

    test('invalid JSON throws PriceUnavailable', () async {
      final http =
          FakeHttpClient({_aaplUrl: const HttpResponse(200, 'not json')});
      expect(
        () => YahooFinanceProvider(http).fetchQuote('AAPL'),
        throwsA(isA<PriceUnavailable>()),
      );
    });

    test('a network exception throws PriceUnavailable', () async {
      expect(
        () => YahooFinanceProvider(_ThrowingHttp()).fetchQuote('AAPL'),
        throwsA(isA<PriceUnavailable>()),
      );
    });
  });
}
