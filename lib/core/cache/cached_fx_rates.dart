import 'package:decimal/decimal.dart';

import '../model/calculations.dart';
import '../model/currency.dart';
import 'fx_cache.dart';

/// Thrown by [CachedFxRates] when a needed rate isn't in the cache, so callers
/// can show "—" instead of a wrong number.
class FxUnavailable implements Exception {
  final Currency from;
  final Currency to;
  final DateTime? date;

  const FxUnavailable(this.from, this.to, this.date);

  @override
  String toString() =>
      'FxUnavailable: ${from.code}->${to.code}${date == null ? ' latest' : ' @ $date'}';
}

/// An [FxRates] backed by the [FxCache]: dated rates for purchase-date history,
/// the fresh latest rate for current value. Throws [FxUnavailable] on a miss.
class CachedFxRates implements FxRates {
  final FxCache cache;
  final DateTime now;
  final Duration ttl;

  const CachedFxRates(this.cache, {required this.now, required this.ttl});

  @override
  Decimal rateFor(Currency from, Currency to, {DateTime? date}) {
    if (from == to) return Decimal.fromInt(1);
    if (date != null) {
      final entry = cache.dated(from, to, date);
      if (entry != null) return entry.rate;
      throw FxUnavailable(from, to, date);
    }
    final entry = cache.freshLatest(from, to, ttl: ttl, now: now);
    if (entry != null) return entry.rate;
    throw FxUnavailable(from, to, null);
  }
}
