import 'package:decimal/decimal.dart';

import 'asset.dart';
import 'currency.dart';
import 'lot.dart';
import 'money.dart';

/// Source of FX rates for currency conversion. Implementations may be backed by
/// a cache or a live provider; the calculations below depend only on this
/// abstraction (Dependency Inversion).
abstract interface class FxRates {
  /// Multiplier that converts an amount in [from] to [to], as of [date]
  /// (null = latest). Must throw if the rate is unavailable.
  Decimal rateFor(Currency from, Currency to, {DateTime? date});
}

/// Converts [amount] into [to] using [rates] as of [date]. No-op (and no rate
/// lookup) when the amount is already in the target currency.
Money convertMoney(Money amount, Currency to, FxRates rates, {DateTime? date}) {
  if (amount.currency == to) return amount;
  final rate = rates.rateFor(amount.currency, to, date: date);
  return Money(amount.amount * rate, to);
}

/// Total units held across [lots].
Decimal totalQuantity(Iterable<Lot> lots) =>
    lots.fold(Decimal.zero, (sum, lot) => sum + lot.quantity);

/// Cost basis of [lots] in [base], converting each lot at its purchase-date FX.
Money costBasisInBase(Iterable<Lot> lots, Currency base, FxRates rates) {
  var total = Money.zero(base);
  for (final lot in lots) {
    total += convertMoney(lot.cost, base, rates, date: lot.date);
  }
  return total;
}

/// Valuation of a single asset, expressed in the base currency.
class AssetValuation {
  final Asset asset;
  final Decimal quantity;
  final Money costBasis;
  final Money value;

  const AssetValuation({
    required this.asset,
    required this.quantity,
    required this.costBasis,
    required this.value,
  });

  /// Absolute gain or loss in the base currency.
  Money get gain => value - costBasis;

  /// Gain as a fraction of cost basis (0.1 == +10%). Null when cost basis is
  /// zero, where a percentage is undefined.
  Decimal? get gainFraction => costBasis.isZero
      ? null
      : (gain.amount / costBasis.amount).toDecimal(scaleOnInfinitePrecision: 12);

  /// Gain as a percentage, or null when cost basis is zero.
  Decimal? get gainPercent {
    final fraction = gainFraction;
    return fraction == null ? null : fraction * Decimal.fromInt(100);
  }
}

/// Values a single asset given its current [unitPrice] (in the asset's pricing
/// currency). Cost basis uses each lot's purchase-date FX; current value uses
/// the rate as of [asOf] (null = latest).
AssetValuation valueAsset({
  required Asset asset,
  required Iterable<Lot> lots,
  required Money unitPrice,
  required Currency base,
  required FxRates rates,
  DateTime? asOf,
}) {
  final quantity = totalQuantity(lots);
  final costBasis = costBasisInBase(lots, base, rates);
  final nativeValue = unitPrice.times(quantity);
  final value = convertMoney(nativeValue, base, rates, date: asOf);
  return AssetValuation(
    asset: asset,
    quantity: quantity,
    costBasis: costBasis,
    value: value,
  );
}

/// One asset together with its lots and resolved current unit price.
class Position {
  final Asset asset;
  final List<Lot> lots;
  final Money unitPrice;

  const Position({
    required this.asset,
    required this.lots,
    required this.unitPrice,
  });
}

/// Whole-portfolio valuation in the base currency.
class PortfolioValuation {
  final Currency base;
  final List<AssetValuation> assets;

  const PortfolioValuation({required this.base, required this.assets});

  Money get totalValue =>
      assets.fold(Money.zero(base), (sum, a) => sum + a.value);

  Money get totalCostBasis =>
      assets.fold(Money.zero(base), (sum, a) => sum + a.costBasis);

  Money get totalGain => totalValue - totalCostBasis;

  /// Total gain as a fraction of total cost basis, or null when cost is zero.
  Decimal? get totalGainFraction => totalCostBasis.isZero
      ? null
      : (totalGain.amount / totalCostBasis.amount)
          .toDecimal(scaleOnInfinitePrecision: 12);

  Decimal? get totalGainPercent {
    final fraction = totalGainFraction;
    return fraction == null ? null : fraction * Decimal.fromInt(100);
  }
}

/// Values an entire portfolio from [positions], in [base], as of [asOf].
PortfolioValuation valuePortfolio({
  required Iterable<Position> positions,
  required Currency base,
  required FxRates rates,
  DateTime? asOf,
}) {
  final valuations = [
    for (final position in positions)
      valueAsset(
        asset: position.asset,
        lots: position.lots,
        unitPrice: position.unitPrice,
        base: base,
        rates: rates,
        asOf: asOf,
      ),
  ];
  return PortfolioValuation(base: base, assets: valuations);
}
