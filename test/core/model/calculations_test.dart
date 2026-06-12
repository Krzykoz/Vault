import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/calculations.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';

/// FX rates backed by a closure, so each test states exactly the rates it needs.
class _FnRates implements FxRates {
  final Decimal Function(Currency from, Currency to, DateTime? date) fn;
  const _FnRates(this.fn);

  @override
  Decimal rateFor(Currency from, Currency to, {DateTime? date}) =>
      fn(from, to, date);
}

class _ThrowingRates implements FxRates {
  const _ThrowingRates();
  @override
  Decimal rateFor(Currency from, Currency to, {DateTime? date}) =>
      throw StateError('rate should not be requested');
}

void main() {
  final usd = Currency('USD');
  final eur = Currency('EUR');
  final purchaseDate = DateTime.utc(2023, 6, 1);

  // EUR->USD was 1.10 on the purchase date, 1.20 today.
  final rates = _FnRates((from, to, date) {
    if (from.code == 'EUR' && to.code == 'USD') {
      final isPurchaseDate = date != null && date.isAtSameMomentAs(purchaseDate);
      return Decimal.parse(isPurchaseDate ? '1.10' : '1.20');
    }
    throw StateError('unexpected rate ${from.code}->${to.code} @ $date');
  });

  Lot lot(String id, String assetId, String qty, Money unitCost, DateTime d) =>
      Lot(
        id: id,
        assetId: assetId,
        quantity: Decimal.parse(qty),
        unitCost: unitCost,
        date: d,
      );

  group('totalQuantity', () {
    test('sums lot quantities', () {
      final lots = [
        lot('1', 'a', '2', Money.parse('1', usd), purchaseDate),
        lot('2', 'a', '3', Money.parse('1', usd), purchaseDate),
      ];
      expect(totalQuantity(lots), Decimal.fromInt(5));
    });

    test('empty is zero', () {
      expect(totalQuantity(const []), Decimal.zero);
    });
  });

  group('convertMoney', () {
    test('same currency is a no-op and never queries rates', () {
      final amount = Money.parse('5', usd);
      expect(convertMoney(amount, usd, const _ThrowingRates()), amount);
    });

    test('converts using the dated rate', () {
      expect(
        convertMoney(Money.parse('100', eur), usd, rates, date: purchaseDate),
        Money.parse('110.00', usd),
      );
    });
  });

  group('costBasisInBase', () {
    test('uses the purchase-date FX rate, not the latest', () {
      // 10 * EUR50 = EUR500, at the purchase-date rate 1.10 => USD 550 (not 600).
      final lots = [lot('l', 'b', '10', Money.parse('50', eur), purchaseDate)];
      expect(costBasisInBase(lots, usd, rates), Money.parse('550.00', usd));
    });
  });

  group('valueAsset', () {
    test('single-currency gain', () {
      final apple = Asset(
        id: 'a',
        type: AssetType.stock,
        name: 'Apple',
        nativeCurrency: usd,
        symbol: 'AAPL',
      );
      final v = valueAsset(
        asset: apple,
        lots: [lot('l', 'a', '2', Money.parse('100', usd), purchaseDate)],
        unitPrice: Money.parse('150', usd),
        base: usd,
        rates: rates,
      );
      expect(v.quantity, Decimal.fromInt(2));
      expect(v.costBasis, Money.parse('200', usd));
      expect(v.value, Money.parse('300', usd));
      expect(v.gain, Money.parse('100', usd));
      expect(v.gainPercent, Decimal.fromInt(50));
    });

    test('multi-currency: cost at purchase-date FX, value at latest FX', () {
      final sap = Asset(
        id: 'b',
        type: AssetType.stock,
        name: 'SAP',
        nativeCurrency: eur,
        symbol: 'SAP',
      );
      final v = valueAsset(
        asset: sap,
        lots: [lot('l', 'b', '10', Money.parse('50', eur), purchaseDate)],
        unitPrice: Money.parse('60', eur),
        base: usd,
        rates: rates,
      );
      expect(v.costBasis, Money.parse('550.00', usd)); // 500 EUR * 1.10
      expect(v.value, Money.parse('720.00', usd)); // 600 EUR * 1.20
      expect(v.gain, Money.parse('170.00', usd));
      expect(v.gainPercent, isNotNull);
      expect(v.gainPercent! >= Decimal.parse('30.90'), isTrue);
      expect(v.gainPercent! <= Decimal.parse('30.92'), isTrue);
    });

    test('zero cost basis yields a null percentage, not a divide-by-zero', () {
      final freebie = Asset(
        id: 'f',
        type: AssetType.stock,
        name: 'Freebie',
        nativeCurrency: usd,
        symbol: 'FREE',
      );
      final v = valueAsset(
        asset: freebie,
        lots: [lot('l', 'f', '5', Money.parse('0', usd), purchaseDate)],
        unitPrice: Money.parse('10', usd),
        base: usd,
        rates: rates,
      );
      expect(v.costBasis, Money.zero(usd));
      expect(v.value, Money.parse('50', usd));
      expect(v.gain, Money.parse('50', usd));
      expect(v.gainFraction, isNull);
      expect(v.gainPercent, isNull);
    });
  });

  group('valuePortfolio', () {
    test('aggregates value, cost, and gain across currencies', () {
      final apple = Asset(
        id: 'a',
        type: AssetType.stock,
        name: 'Apple',
        nativeCurrency: usd,
        symbol: 'AAPL',
      );
      final sap = Asset(
        id: 'b',
        type: AssetType.stock,
        name: 'SAP',
        nativeCurrency: eur,
        symbol: 'SAP',
      );
      final portfolio = valuePortfolio(
        positions: [
          Position(
            asset: apple,
            lots: [lot('l1', 'a', '2', Money.parse('100', usd), purchaseDate)],
            unitPrice: Money.parse('150', usd),
          ),
          Position(
            asset: sap,
            lots: [lot('l2', 'b', '10', Money.parse('50', eur), purchaseDate)],
            unitPrice: Money.parse('60', eur),
          ),
        ],
        base: usd,
        rates: rates,
      );
      expect(portfolio.totalValue, Money.parse('1020.00', usd));
      expect(portfolio.totalCostBasis, Money.parse('750.00', usd));
      expect(portfolio.totalGain, Money.parse('270.00', usd));
      expect(portfolio.totalGainPercent, Decimal.fromInt(36));
    });

    test('empty portfolio is zero with an undefined percentage', () {
      final portfolio = valuePortfolio(
        positions: const [],
        base: usd,
        rates: rates,
      );
      expect(portfolio.totalValue, Money.zero(usd));
      expect(portfolio.totalCostBasis, Money.zero(usd));
      expect(portfolio.totalGain, Money.zero(usd));
      expect(portfolio.totalGainFraction, isNull);
      expect(portfolio.totalGainPercent, isNull);
    });
  });
}
