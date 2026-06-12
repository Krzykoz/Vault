import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../model/asset.dart';
import '../model/currency.dart';
import '../model/money.dart';
import '../ports/http_client.dart';
import 'price_provider.dart';

/// Prices stocks, ETFs, crypto, and commodities from Yahoo Finance's public
/// chart endpoint. The price is read from the raw response as an exact decimal
/// (never parsed through `double`), so money stays precise.
class YahooFinanceProvider implements PriceProvider {
  final HttpClient _http;

  YahooFinanceProvider(this._http);

  @override
  String get id => 'yahoo';

  @override
  bool supports(Asset asset) {
    final symbol = asset.symbol;
    if (symbol == null || symbol.isEmpty) return false;
    switch (asset.type) {
      case AssetType.stock:
      case AssetType.etf:
      case AssetType.crypto:
      case AssetType.commodity:
        return true;
      case AssetType.cash:
      case AssetType.manual:
        return false;
    }
  }

  static Uri _chartUrl(String symbol) => Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/'
        '${Uri.encodeComponent(symbol)}?interval=1d&range=1d',
      );

  @override
  Future<PriceQuote> fetchQuote(String symbol) async {
    final HttpResponse response;
    try {
      response = await _http.get(
        _chartUrl(symbol),
        headers: const {'User-Agent': 'Vault/1.0'},
      );
    } catch (_) {
      throw PriceUnavailable('network error for $symbol');
    }
    if (!response.isOk) {
      throw PriceUnavailable('HTTP ${response.statusCode} for $symbol');
    }
    return _parse(symbol, response.body);
  }

  PriceQuote _parse(String symbol, String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw PriceUnavailable('invalid JSON for $symbol');
    }
    final chart = decoded is Map ? decoded['chart'] : null;
    if (chart is! Map) throw PriceUnavailable('unexpected response for $symbol');
    if (chart['error'] != null) {
      throw PriceUnavailable('Yahoo error for $symbol');
    }
    final results = chart['result'];
    if (results is! List || results.isEmpty) {
      throw PriceUnavailable('no data for $symbol');
    }
    final meta = (results.first as Map)['meta'];
    if (meta is! Map) throw PriceUnavailable('no meta for $symbol');

    final currencyCode = meta['currency'];
    if (currencyCode is! String || currencyCode.isEmpty) {
      throw PriceUnavailable('no currency for $symbol');
    }

    final price = _extractDecimal(body, 'regularMarketPrice', symbol);
    final time = meta['regularMarketTime'];
    final asOf = time is int
        ? DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true)
        : DateTime.now().toUtc();

    return PriceQuote(Money(price, Currency(currencyCode)), asOf);
  }

  /// Reads a numeric field from the raw body as exact text, so the price never
  /// passes through a `double`. Scientific notation is not accepted.
  Decimal _extractDecimal(String body, String key, String symbol) {
    final match =
        RegExp('"$key"' r'\s*:\s*(-?[0-9]+(?:\.[0-9]+)?)').firstMatch(body);
    if (match == null) throw PriceUnavailable('no $key for $symbol');
    try {
      return Decimal.parse(match.group(1)!);
    } catch (_) {
      throw PriceUnavailable('unparseable $key for $symbol');
    }
  }
}
