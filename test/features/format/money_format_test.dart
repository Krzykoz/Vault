import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/features/format/money_format.dart';

void main() {
  Money money(String amount, String code) => Money.parse(amount, Currency(code));

  group('formatMoney', () {
    test('uses the symbol, grouping, and decimals of the en_US locale', () {
      expect(formatMoney(money('1234.5', 'USD'), locale: 'en_US'), r'$1,234.50');
    });

    test('uses European separators and symbol placement', () {
      final out = formatMoney(money('1234.5', 'EUR'), locale: 'de_DE');
      expect(out, contains('1.234,50'));
      expect(out, contains('€'));
    });

    test('honours currencies with no minor unit (JPY)', () {
      expect(formatMoney(money('1235', 'JPY'), locale: 'en_US'), '¥1,235');
    });

    test('rounds for display without touching the stored precision', () {
      expect(formatMoney(money('1234.567', 'USD'), locale: 'en_US'), r'$1,234.57');
    });

    test('shows a placeholder for a missing value', () {
      expect(formatMoney(null), '—');
    });
  });

  group('formatPercent', () {
    test('prefixes gains with a plus', () {
      expect(formatPercent(Decimal.parse('12.3')), '+12.30%');
    });

    test('keeps the minus on losses', () {
      expect(formatPercent(Decimal.parse('-1.2')), '-1.20%');
    });

    test('treats zero as non-negative', () {
      expect(formatPercent(Decimal.zero), '+0.00%');
    });
  });
}
