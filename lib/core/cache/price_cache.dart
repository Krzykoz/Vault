import '../model/money.dart';

/// A cached price for one `(providerId, symbol)` pair, with the time it was
/// fetched so freshness can be judged against a TTL.
class PriceCacheEntry {
  final String providerId;
  final String symbol;
  final Money price;
  final DateTime fetchedAt;

  const PriceCacheEntry({
    required this.providerId,
    required this.symbol,
    required this.price,
    required this.fetchedAt,
  });

  Map<String, dynamic> toMap() => {
        'providerId': providerId,
        'symbol': symbol,
        'price': price.toMap(),
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      };

  factory PriceCacheEntry.fromMap(Map<String, dynamic> map) => PriceCacheEntry(
        providerId: map['providerId'] as String,
        symbol: map['symbol'] as String,
        price: Money.fromMap((map['price'] as Map).cast<String, dynamic>()),
        fetchedAt: DateTime.parse(map['fetchedAt'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is PriceCacheEntry &&
      other.providerId == providerId &&
      other.symbol == symbol &&
      other.price == price &&
      other.fetchedAt.isAtSameMomentAs(fetchedAt);

  @override
  int get hashCode =>
      Object.hash(providerId, symbol, price, fetchedAt.toUtc());
}

/// An immutable cache of fetched prices. [put] returns a new cache; freshness is
/// judged by passing the current time, so callers stay in control of the clock.
class PriceCache {
  final Map<String, PriceCacheEntry> _entries;

  const PriceCache._(this._entries);

  factory PriceCache([Iterable<PriceCacheEntry> entries = const []]) =>
      PriceCache._({
        for (final entry in entries) _key(entry.providerId, entry.symbol): entry,
      });

  static String _key(String providerId, String symbol) =>
      '$providerId\u0000$symbol';

  PriceCacheEntry? get(String providerId, String symbol) =>
      _entries[_key(providerId, symbol)];

  /// The first cached entry for [symbol] from any provider, or null.
  PriceCacheEntry? bySymbol(String symbol) {
    for (final entry in _entries.values) {
      if (entry.symbol == symbol) return entry;
    }
    return null;
  }

  bool isFresh(PriceCacheEntry entry,
          {required Duration ttl, required DateTime now}) =>
      now.difference(entry.fetchedAt) <= ttl;

  /// The cached price if present and no older than [ttl] at [now]; else null.
  PriceCacheEntry? fresh(
    String providerId,
    String symbol, {
    required Duration ttl,
    required DateTime now,
  }) {
    final entry = get(providerId, symbol);
    if (entry == null) return null;
    return isFresh(entry, ttl: ttl, now: now) ? entry : null;
  }

  PriceCache put(PriceCacheEntry entry) {
    final next = Map<String, PriceCacheEntry>.from(_entries);
    next[_key(entry.providerId, entry.symbol)] = entry;
    return PriceCache._(next);
  }

  Iterable<PriceCacheEntry> get entries => _entries.values;

  int get length => _entries.length;

  List<Map<String, dynamic>> toMaps() => [for (final e in entries) e.toMap()];

  factory PriceCache.fromMaps(List<dynamic> list) => PriceCache([
        for (final e in list)
          PriceCacheEntry.fromMap((e as Map).cast<String, dynamic>()),
      ]);
}
