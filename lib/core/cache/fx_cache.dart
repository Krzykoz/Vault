import 'package:decimal/decimal.dart';

import '../model/currency.dart';

/// A cached FX rate. A [date] means a historical rate for that calendar day
/// (used for purchase-date cost basis); a null [date] is the latest spot rate,
/// whose freshness is judged against a TTL via [fetchedAt].
class FxRateEntry {
  final Currency base;
  final Currency quote;
  final Decimal rate;
  final DateTime fetchedAt;
  final DateTime? date;

  const FxRateEntry({
    required this.base,
    required this.quote,
    required this.rate,
    required this.fetchedAt,
    this.date,
  });

  Map<String, dynamic> toMap() => {
        'base': base.code,
        'quote': quote.code,
        'rate': rate.toString(),
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'date': date == null ? null : FxCache.dayStart(date!).toIso8601String(),
      };

  factory FxRateEntry.fromMap(Map<String, dynamic> map) => FxRateEntry(
        base: Currency(map['base'] as String),
        quote: Currency(map['quote'] as String),
        rate: Decimal.parse(map['rate'] as String),
        fetchedAt: DateTime.parse(map['fetchedAt'] as String),
        date: map['date'] == null ? null : DateTime.parse(map['date'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is FxRateEntry &&
      other.base == base &&
      other.quote == quote &&
      other.rate == rate &&
      other.fetchedAt.isAtSameMomentAs(fetchedAt) &&
      FxCache.dayKeyOrNull(other.date) == FxCache.dayKeyOrNull(date);

  @override
  int get hashCode =>
      Object.hash(base, quote, rate, fetchedAt.toUtc(), FxCache.dayKeyOrNull(date));
}

/// An immutable cache of FX rates, keyed by `(base, quote, day | latest)`.
/// Dated (historical) rates never expire; latest rates use a TTL.
class FxCache {
  final Map<String, FxRateEntry> _entries;

  const FxCache._(this._entries);

  factory FxCache([Iterable<FxRateEntry> entries = const []]) => FxCache._({
        for (final entry in entries)
          _key(entry.base, entry.quote, entry.date): entry,
      });

  /// The UTC calendar day (`YYYY-MM-DD`) a [date] falls on.
  static String dayKey(DateTime date) {
    final utc = date.toUtc();
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$month-$day';
  }

  static String? dayKeyOrNull(DateTime? date) =>
      date == null ? null : dayKey(date);

  /// Midnight UTC of the calendar day [date] falls on. Used for serialization so
  /// a dated rate round-trips to the same UTC day regardless of local timezone.
  static DateTime dayStart(DateTime date) {
    final utc = date.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }

  static String _key(Currency base, Currency quote, DateTime? date) =>
      '${base.code}\u0000${quote.code}\u0000${date == null ? 'latest' : dayKey(date)}';

  /// The historical rate for the calendar day of [date], or null. Dated rates
  /// are fixed history, so they do not expire.
  FxRateEntry? dated(Currency base, Currency quote, DateTime date) =>
      _entries[_key(base, quote, date)];

  /// The latest spot rate regardless of freshness, or null.
  FxRateEntry? latest(Currency base, Currency quote) =>
      _entries[_key(base, quote, null)];

  /// The latest spot rate if no older than [ttl] at [now]; else null.
  FxRateEntry? freshLatest(
    Currency base,
    Currency quote, {
    required Duration ttl,
    required DateTime now,
  }) {
    final entry = latest(base, quote);
    if (entry == null) return null;
    return now.difference(entry.fetchedAt) <= ttl ? entry : null;
  }

  FxCache put(FxRateEntry entry) {
    final next = Map<String, FxRateEntry>.from(_entries);
    next[_key(entry.base, entry.quote, entry.date)] = entry;
    return FxCache._(next);
  }

  Iterable<FxRateEntry> get entries => _entries.values;

  int get length => _entries.length;

  List<Map<String, dynamic>> toMaps() => [for (final e in entries) e.toMap()];

  factory FxCache.fromMaps(List<dynamic> list) => FxCache([
        for (final e in list)
          FxRateEntry.fromMap((e as Map).cast<String, dynamic>()),
      ]);
}
