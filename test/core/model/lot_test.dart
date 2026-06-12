import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';

void main() {
  final usd = Currency('USD');
  final eur = Currency('EUR');

  Lot sample({Money? fee}) => Lot(
        id: 'l1',
        assetId: 'a1',
        quantity: Decimal.parse('3'),
        unitCost: Money.parse('100.00', usd),
        date: DateTime.utc(2024, 1, 15),
        fee: fee,
      );

  group('Lot', () {
    test('cost = unitCost * quantity', () {
      expect(sample().cost, Money.parse('300.00', usd));
    });

    test('cost includes a same-currency fee', () {
      expect(
        sample(fee: Money.parse('5', usd)).cost,
        Money.parse('305.00', usd),
      );
    });

    test('cost throws on a mismatched fee currency', () {
      expect(() => sample(fee: Money.parse('5', eur)).cost, throwsArgumentError);
    });

    test('map round-trip', () {
      final l = sample(fee: Money.parse('5', usd));
      expect(Lot.fromMap(l.toMap()), l);
    });

    test('value equality ignores instant representation', () {
      final asLocal =
          sample().copyWith(date: DateTime.utc(2024, 1, 15).toLocal());
      expect(asLocal, sample());
    });
  });
}
