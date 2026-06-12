import 'package:decimal/decimal.dart';

import '../../core/cache/cached_fx_rates.dart';
import '../../core/cache/fx_cache.dart';
import '../../core/cache/price_cache.dart';
import '../../core/model/asset.dart';
import '../../core/model/calculations.dart';
import '../../core/model/currency.dart';
import '../../core/model/money.dart';
import '../../core/model/payload.dart';

/// One asset's line on the dashboard, valued in the base currency. [value],
/// [costBasis], and [gain] are null when a needed price or FX rate is missing,
/// so the UI shows "—" instead of a wrong figure.
class AssetRow {
  final Asset asset;
  final Decimal quantity;
  final Money? value;
  final Money? costBasis;
  final Money? gain;
  final Decimal? gainPercent;
  final bool priced;

  const AssetRow({
    required this.asset,
    required this.quantity,
    required this.priced,
    this.value,
    this.costBasis,
    this.gain,
    this.gainPercent,
  });
}

/// The whole portfolio valued in the base currency. Totals sum only the rows
/// whose value/cost could actually be computed.
class PortfolioView {
  final Currency base;
  final List<AssetRow> rows;
  final Money totalValue;
  final Money totalCostBasis;

  const PortfolioView({
    required this.base,
    required this.rows,
    required this.totalValue,
    required this.totalCostBasis,
  });

  Money get totalGain => totalValue - totalCostBasis;

  Decimal? get totalGainPercent => totalCostBasis.isZero
      ? null
      : (totalGain.amount / totalCostBasis.amount)
              .toDecimal(scaleOnInfinitePrecision: 12) *
          Decimal.fromInt(100);
}

Decimal? _percent(Money gain, Money costBasis) => costBasis.isZero
    ? null
    : (gain.amount / costBasis.amount).toDecimal(scaleOnInfinitePrecision: 12) *
        Decimal.fromInt(100);

Money? _resolvePrice(
  Asset asset,
  PriceCache prices,
  String providerId,
  Duration ttl,
  DateTime now,
) {
  if (asset.manualPrice != null) return asset.manualPrice;
  final symbol = asset.symbol;
  if (symbol != null && symbol.isNotEmpty) {
    return prices.fresh(providerId, symbol, ttl: ttl, now: now)?.price;
  }
  return null;
}

/// Builds the dashboard view from a decrypted [payload]. Prices come from each
/// asset's manual price or the [priceCache]; conversions use the [fxCache].
/// Anything that can't be priced/converted is left null.
PortfolioView buildPortfolioView(
  VaultPayload payload, {
  required DateTime now,
  PriceCache? priceCache,
  FxCache? fxCache,
  String providerId = '',
}) {
  final base = payload.settings.baseCurrency;
  final prices = priceCache ?? PriceCache();
  final rates = CachedFxRates(
    fxCache ?? FxCache(),
    now: now,
    ttl: payload.settings.fxTtl,
  );

  final rows = <AssetRow>[];
  var totalValue = Money.zero(base);
  var totalCost = Money.zero(base);

  for (final asset in payload.assets) {
    final lots = payload.lots.where((l) => l.assetId == asset.id).toList();
    final quantity = totalQuantity(lots);

    Money? costBasis;
    try {
      costBasis = costBasisInBase(lots, base, rates);
    } on FxUnavailable {
      costBasis = null;
    }

    final unitPrice =
        _resolvePrice(asset, prices, providerId, payload.settings.priceTtl, now);
    Money? value;
    if (unitPrice != null) {
      try {
        value = convertMoney(unitPrice.times(quantity), base, rates);
      } on FxUnavailable {
        value = null;
      }
    }

    Money? gain;
    Decimal? gainPercent;
    if (value != null && costBasis != null) {
      gain = value - costBasis;
      gainPercent = _percent(gain, costBasis);
    }

    if (value != null) {
      totalValue += value;
      if (costBasis != null) totalCost += costBasis;
    }

    rows.add(AssetRow(
      asset: asset,
      quantity: quantity,
      value: value,
      costBasis: costBasis,
      gain: gain,
      gainPercent: gainPercent,
      priced: unitPrice != null,
    ));
  }

  return PortfolioView(
    base: base,
    rows: rows,
    totalValue: totalValue,
    totalCostBasis: totalCost,
  );
}
