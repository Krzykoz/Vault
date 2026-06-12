import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/money.dart';

void main() {
  final usd = Currency('USD');

  Asset sample() => Asset(
        id: 'a1',
        type: AssetType.stock,
        name: 'Apple',
        nativeCurrency: usd,
        symbol: 'AAPL',
      );

  group('Asset', () {
    test('isPriced reflects a usable symbol', () {
      expect(sample().isPriced, isTrue);
      expect(sample().copyWith(symbol: '').isPriced, isFalse);
      expect(
        Asset(id: 'c', type: AssetType.cash, name: 'Cash', nativeCurrency: usd)
            .isPriced,
        isFalse,
      );
    });

    test('copyWith overrides only the given fields', () {
      final updated = sample().copyWith(name: 'Apple Inc.');
      expect(updated.name, 'Apple Inc.');
      expect(updated.symbol, 'AAPL');
    });

    test('map round-trip with and without optionals', () {
      final priced = sample().copyWith(manualPrice: Money.parse('190.5', usd));
      expect(Asset.fromMap(priced.toMap()), priced);

      final manual = Asset(
        id: 'm',
        type: AssetType.manual,
        name: 'Flat',
        nativeCurrency: usd,
      );
      expect(Asset.fromMap(manual.toMap()), manual);
    });

    test('value equality', () {
      expect(sample(), sample());
      expect(sample() == sample().copyWith(id: 'other'), isFalse);
    });
  });
}
