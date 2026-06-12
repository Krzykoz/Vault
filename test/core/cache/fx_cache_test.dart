import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/cache/fx_cache.dart';
import 'package:vault/core/model/currency.dart';

void main() {
  final eur = Currency('EUR');
  final usd = Currency('USD');
  final fetchedAt = DateTime.utc(2024, 6, 1, 12);
  final purchaseDate = DateTime.utc(2023, 5, 1, 14, 30); // a time mid-day

  FxRateEntry datedEntry() => FxRateEntry(
        base: eur,
        quote: usd,
        rate: Decimal.parse('1.10'),
        fetchedAt: fetchedAt,
        date: purchaseDate,
      );

  FxRateEntry latestEntry() => FxRateEntry(
        base: eur,
        quote: usd,
        rate: Decimal.parse('1.20'),
        fetchedAt: fetchedAt,
      );

  group('FxCache dated lookups', () {
    test('finds a historical rate by calendar day, ignoring time of day', () {
      final cache = FxCache().put(datedEntry());
      // Same day, different time -> still a hit.
      expect(
        cache.dated(eur, usd, DateTime.utc(2023, 5, 1, 9)),
        datedEntry(),
      );
      // Different day -> miss.
      expect(cache.dated(eur, usd, DateTime.utc(2023, 5, 2)), isNull);
    });

    test('dated rates do not expire', () {
      final cache = FxCache().put(datedEntry());
      final farFuture = fetchedAt.add(const Duration(days: 3650));
      expect(cache.dated(eur, usd, purchaseDate), isNotNull);
      // freshLatest only applies to spot rates, not dated ones.
      expect(
        cache.freshLatest(eur, usd, ttl: const Duration(hours: 1), now: farFuture),
        isNull,
      );
    });
  });

  group('FxCache latest vs dated', () {
    test('a latest rate and a dated rate coexist for the same pair', () {
      final cache = FxCache().put(datedEntry()).put(latestEntry());
      expect(cache.length, 2);
      expect(cache.latest(eur, usd)!.rate, Decimal.parse('1.20'));
      expect(cache.dated(eur, usd, purchaseDate)!.rate, Decimal.parse('1.10'));
    });

    test('freshLatest honours the TTL', () {
      final cache = FxCache().put(latestEntry());
      const ttl = Duration(hours: 12);
      expect(
        cache.freshLatest(eur, usd,
            ttl: ttl, now: fetchedAt.add(const Duration(hours: 11))),
        isNotNull,
      );
      expect(
        cache.freshLatest(eur, usd,
            ttl: ttl, now: fetchedAt.add(const Duration(hours: 13))),
        isNull,
      );
    });
  });

  group('FxCache serialization', () {
    test('round-trips dated and latest entries', () {
      final cache = FxCache().put(datedEntry()).put(latestEntry());
      final restored = FxCache.fromMaps(cache.toMaps());
      expect(restored.length, 2);
      expect(restored.latest(eur, usd)!.rate, Decimal.parse('1.20'));
      expect(restored.dated(eur, usd, purchaseDate)!.rate, Decimal.parse('1.10'));
    });
  });
}
