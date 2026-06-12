import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/money.dart';

void main() {
  final usd = Currency('USD');
  final eur = Currency('EUR');

  group('Money', () {
    test('parse and zero', () {
      expect(Money.parse('12.34', usd).amount, Decimal.parse('12.34'));
      expect(Money.zero(usd).isZero, isTrue);
    });

    test('adds and subtracts within a currency', () {
      final a = Money.parse('10.00', usd);
      final b = Money.parse('2.50', usd);
      expect(a + b, Money.parse('12.50', usd));
      expect(a - b, Money.parse('7.50', usd));
    });

    test('rejects cross-currency arithmetic', () {
      expect(
        () => Money.parse('1', usd) + Money.parse('1', eur),
        throwsArgumentError,
      );
      expect(
        () => Money.parse('1', usd).compareTo(Money.parse('1', eur)),
        throwsArgumentError,
      );
    });

    test('times scales by a quantity', () {
      expect(
        Money.parse('3.00', usd).times(Decimal.parse('1.5')),
        Money.parse('4.50', usd),
      );
    });

    test('isNegative', () {
      expect(Money.parse('-1', usd).isNegative, isTrue);
      expect(Money.parse('1', usd).isNegative, isFalse);
    });

    test('compareTo orders amounts', () {
      expect(
        Money.parse('1', usd).compareTo(Money.parse('2', usd)),
        lessThan(0),
      );
    });

    test('map round-trip', () {
      final m = Money.parse('1234.56', usd);
      expect(Money.fromMap(m.toMap()), m);
    });

    test('value equality', () {
      expect(Money.parse('5', usd), Money.parse('5', usd));
      expect(Money.parse('5', usd) == Money.parse('5', eur), isFalse);
    });
  });
}
