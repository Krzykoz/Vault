import 'dart:convert';

import 'package:decimal/decimal.dart';

import '../model/asset.dart';
import '../model/currency.dart';
import '../model/money.dart';
import '../ports/http_client.dart';
import 'fx_provider.dart';
import 'price_provider.dart';

/// Prices stocks, ETFs, crypto, and commodities, and FX rates for currency
/// pairs, from Yahoo Finance's public chart endpoint. Numbers are read from the
/// raw response as exact decimals (never through a `double`), so money stays
/// precise.
class YahooFinanceProvider implements PriceProvider, FxProvider {
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

  /// The 1-day chart URL for a price symbol or currency-pair symbol.
  static Uri quoteUrl(String symbol) => Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/'
        '${Uri.encodeComponent(symbol)}?interval=1d&range=1d',
      );

  /// The chart URL for an FX pair, latest or for a specific [date].
  static Uri fxUrl(Currency base, Currency quote, {DateTime? date}) {
    final symbol = '${base.code}${quote.code}=X';
    if (date == null) return quoteUrl(symbol);
    final utc = date.toUtc();
    final dayStart = DateTime.utc(utc.year, utc.month, utc.day);
    final start = dayStart.millisecondsSinceEpoch ~/ 1000;
    final end = start + 86400;
    return Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/'
      '${Uri.encodeComponent(symbol)}?period1=$start&period2=$end&interval=1d',
    );
  }

  @override
  Future<PriceQuote> fetchQuote(String symbol) async {
    final HttpResponse response;
    try {
      response = await _http.get(
        quoteUrl(symbol),
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
    if (time is! int) throw PriceUnavailable('no timestamp for $symbol');

    return PriceQuote(
      Money(price, Currency(currencyCode)),
      DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true),
    );
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

  @override
  Future<FxQuote> fetchRate(
    Currency base,
    Currency quote, {
    DateTime? date,
  }) async {
    if (base == quote) {
      return FxQuote(rate: Decimal.fromInt(1), asOf: DateTime.now().toUtc(), date: date);
    }
    final pair = '${base.code}${quote.code}';
    final HttpResponse response;
    try {
      response = await _http.get(
        fxUrl(base, quote, date: date),
        headers: const {'User-Agent': 'Vault/1.0'},
      );
    } catch (_) {
      throw PriceUnavailable('network error for $pair');
    }
    if (!response.isOk) {
      throw PriceUnavailable('HTTP ${response.statusCode} for $pair');
    }

    if (date == null) {
      final rate = _extractDecimal(response.body, 'regularMarketPrice', pair);
      final time = _requireInt(response.body, 'regularMarketTime', pair);
      return FxQuote(
        rate: rate,
        asOf: DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true),
        date: null,
      );
    }

    final rate = _extractClose(response.body, pair);
    final utc = date.toUtc();
    return FxQuote(
      rate: rate,
      asOf: DateTime.utc(utc.year, utc.month, utc.day),
      date: date,
    );
  }

  /// Reads the first `close` value from a historical chart response as exact text.
  Decimal _extractClose(String body, String pair) {
    final match = RegExp(r'"close"\s*:\s*\[\s*(-?[0-9]+(?:\.[0-9]+)?)')
        .firstMatch(body);
    if (match == null) throw PriceUnavailable('no close for $pair');
    try {
      return Decimal.parse(match.group(1)!);
    } catch (_) {
      throw PriceUnavailable('unparseable close for $pair');
    }
  }

  int _requireInt(String body, String key, String label) {
    final match = RegExp('"$key"' r'\s*:\s*([0-9]+)').firstMatch(body);
    final value = match == null ? null : int.tryParse(match.group(1)!);
    if (value == null) throw PriceUnavailable('no $key for $label');
    return value;
  }
}
