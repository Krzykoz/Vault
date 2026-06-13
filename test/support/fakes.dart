import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/ports/biometric_gate.dart';
import 'package:vault/core/ports/clock.dart';
import 'package:vault/core/ports/file_store.dart';
import 'package:vault/core/ports/http_client.dart';
import 'package:vault/core/ports/secure_store.dart';
import 'package:vault/core/providers/fx_provider.dart';
import 'package:vault/core/providers/price_provider.dart';

/// A [Clock] returning a fixed, settable time.
class FixedClock implements Clock {
  DateTime current;

  FixedClock(this.current);

  @override
  DateTime now() => current;
}

/// In-memory [SecureStore] for tests. [failWrites]/[failReads] simulate a
/// keychain error or a cancelled biometric prompt.
class InMemorySecureStore implements SecureStore {
  final Map<String, String> entries = {};
  bool failWrites = false;
  bool failReads = false;

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('secure-store write failed');
    entries[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('secure-store read failed');
    return entries[key];
  }

  @override
  Future<bool> containsKey(String key) async => entries.containsKey(key);

  @override
  Future<void> delete(String key) async => entries.remove(key);
}

/// In-memory [FileStore] for tests.
class InMemoryFileStore implements FileStore {
  Uint8List? bytes;

  InMemoryFileStore([this.bytes]);

  @override
  Future<Uint8List?> read() async => bytes;

  @override
  Future<void> write(Uint8List data) async => bytes = data;
}

/// A scriptable [BiometricGate] that records how often it was asked.
class FakeBiometricGate implements BiometricGate {
  bool available;
  bool willSucceed;
  int authCalls = 0;

  FakeBiometricGate({this.available = true, this.willSucceed = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    authCalls++;
    return willSucceed;
  }
}

/// An [HttpClient] that returns canned responses keyed by URL and records every
/// request it received.
class FakeHttpClient implements HttpClient {
  final Map<String, HttpResponse> responses;
  final List<Uri> requested = [];

  FakeHttpClient([this.responses = const {}]);

  @override
  Future<HttpResponse> get(Uri url, {Map<String, String>? headers}) async {
    requested.add(url);
    return responses[url.toString()] ?? const HttpResponse(404, '');
  }
}

/// A scriptable price + FX source for refresh tests. Quotes are keyed by symbol;
/// latest rates by `FROMTO`, dated rates by `FROMTO@YYYY-MM-DD`.
class FakeMarket implements PriceProvider, FxProvider {
  final Map<String, Money> quotes;
  final Map<String, Decimal> latestRates;
  final Map<String, Decimal> datedRates;
  final Set<String> failSymbols;

  FakeMarket({
    this.quotes = const {},
    this.latestRates = const {},
    this.datedRates = const {},
    this.failSymbols = const {},
  });

  @override
  String get id => 'fake';

  @override
  bool supports(Asset asset) {
    final symbol = asset.symbol;
    if (symbol == null || symbol.isEmpty) return false;
    return asset.type != AssetType.cash && asset.type != AssetType.manual;
  }

  @override
  Future<PriceQuote> fetchQuote(String symbol) async {
    if (failSymbols.contains(symbol)) throw PriceUnavailable(symbol);
    final price = quotes[symbol];
    if (price == null) throw PriceUnavailable(symbol);
    return PriceQuote(price, DateTime.utc(2024, 1, 1));
  }

  @override
  Future<FxQuote> fetchRate(Currency base, Currency quote, {DateTime? date}) async {
    if (base == quote) {
      return FxQuote(rate: Decimal.fromInt(1), asOf: DateTime.utc(2024, 1, 1), date: date);
    }
    final key = date == null
        ? '${base.code}${quote.code}'
        : '${base.code}${quote.code}@${date.toUtc().toIso8601String().substring(0, 10)}';
    final rate = date == null ? latestRates[key] : datedRates[key];
    if (rate == null) throw PriceUnavailable(key);
    return FxQuote(rate: rate, asOf: DateTime.utc(2024, 1, 1), date: date);
  }
}
