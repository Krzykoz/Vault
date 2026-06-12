import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/cache/price_cache.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/money.dart';

void main() {
  final usd = Currency('USD');
  final fetchedAt = DateTime.utc(2024, 6, 1, 12);

  PriceCacheEntry entry({DateTime? at, String symbol = 'AAPL'}) => PriceCacheEntry(
        providerId: 'yahoo',
        symbol: symbol,
        price: Money.parse('190.25', usd),
        fetchedAt: at ?? fetchedAt,
      );

  group('PriceCache', () {
    test('miss returns null', () {
      expect(PriceCache().get('yahoo', 'AAPL'), isNull);
      expect(
        PriceCache().fresh('yahoo', 'AAPL',
            ttl: const Duration(hours: 1), now: fetchedAt),
        isNull,
      );
    });

    test('hit returns the stored entry', () {
      final cache = PriceCache().put(entry());
      expect(cache.get('yahoo', 'AAPL'), entry());
    });

    test('fresh within the TTL, stale beyond it', () {
      final cache = PriceCache().put(entry());
      final within = fetchedAt.add(const Duration(minutes: 59));
      final beyond = fetchedAt.add(const Duration(minutes: 61));
      const ttl = Duration(hours: 1);
      expect(cache.fresh('yahoo', 'AAPL', ttl: ttl, now: within), isNotNull);
      expect(cache.fresh('yahoo', 'AAPL', ttl: ttl, now: beyond), isNull);
    });

    test('put overwrites the same provider/symbol key', () {
      final newer = entry(at: fetchedAt.add(const Duration(hours: 2)));
      final cache = PriceCache().put(entry()).put(newer);
      expect(cache.length, 1);
      expect(cache.get('yahoo', 'AAPL'), newer);
    });

    test('round-trips through maps', () {
      final cache = PriceCache().put(entry()).put(entry(symbol: 'MSFT'));
      final restored = PriceCache.fromMaps(cache.toMaps());
      expect(restored.length, 2);
      expect(restored.get('yahoo', 'AAPL'), entry());
      expect(restored.get('yahoo', 'MSFT'), entry(symbol: 'MSFT'));
    });
  });
}
