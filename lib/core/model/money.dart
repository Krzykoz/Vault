import 'package:decimal/decimal.dart';

import 'currency.dart';

/// An exact monetary amount in a single [Currency].
///
/// Backed by [Decimal] — never `double` — so money math is exact. Arithmetic
/// across different currencies throws; convert first via an FX rate.
class Money implements Comparable<Money> {
  final Decimal amount;
  final Currency currency;

  const Money(this.amount, this.currency);

  factory Money.parse(String amount, Currency currency) =>
      Money(Decimal.parse(amount), currency);

  static Money zero(Currency currency) => Money(Decimal.zero, currency);

  bool get isNegative => amount < Decimal.zero;

  bool get isZero => amount == Decimal.zero;

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amount + other.amount, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amount - other.amount, currency);
  }

  /// Scales the amount by a unit-less [factor] (e.g. a quantity of shares).
  Money times(Decimal factor) => Money(amount * factor, currency);

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return amount.compareTo(other.amount);
  }

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError(
        'Currency mismatch: $currency vs ${other.currency}',
      );
    }
  }

  Map<String, dynamic> toMap() => {
        'amount': amount.toString(),
        'currency': currency.code,
      };

  factory Money.fromMap(Map<String, dynamic> map) => Money(
        Decimal.parse(map['amount'] as String),
        Currency(map['currency'] as String),
      );

  @override
  bool operator ==(Object other) =>
      other is Money && other.amount == amount && other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => '$amount ${currency.code}';
}
