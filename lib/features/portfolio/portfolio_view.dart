import 'package:decimal/decimal.dart';

import '../../core/cache/cached_fx_rates.dart';
import '../../core/cache/price_cache.dart';
import '../../core/model/asset.dart';
import '../../core/model/calculations.dart';
import '../../core/model/currency.dart';
import '../../core/model/money.dart';
import '../../core/model/payload.dart';

/// One asset's line on the dashboard, valued in the base currency. [value],
/// [costBasis], and [gain] are null when a needed price or FX rate is missing,
/// so the UI shows "—" instead of a wrong figure. [priceAsOf] is when the price
/// was fetched (null for a manual price); [stale] means it is older than the TTL.
class AssetRow {
  final Asset asset;
  final Decimal quantity;
  final Money? value;
  final Money? costBasis;
  final Money? gain;
  final Decimal? gainPercent;
  final bool priced;
  final DateTime? priceAsOf;
  final bool stale;

  const AssetRow({
    required this.asset,
    required this.quantity,
    required this.priced,
    this.value,
    this.costBasis,
    this.gain,
    this.gainPercent,
    this.priceAsOf,
    this.stale = false,
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

({Money price, DateTime? asOf, bool stale})? _resolvePrice(
  Asset asset,
  PriceCache prices,
  Duration ttl,
  DateTime now,
) {
  final manual = asset.manualPrice;
  if (manual != null) return (price: manual, asOf: null, stale: false);
  final symbol = asset.symbol;
  if (symbol != null && symbol.isNotEmpty) {
    final entry = prices.bySymbol(symbol);
    if (entry != null) {
      return (
        price: entry.price,
        asOf: entry.fetchedAt,
        stale: !prices.isFresh(entry, ttl: ttl, now: now),
      );
    }
  }
  return null;
}

/// Builds the dashboard view from a decrypted [payload]. Prices come from each
/// asset's manual price or the cached price; conversions use the cached FX.
/// Anything that can't be priced/converted is left null.
PortfolioView buildPortfolioView(VaultPayload payload, {required DateTime now}) {
  final base = payload.settings.baseCurrency;
  final prices = payload.priceCache;
  final rates = CachedFxRates(
    payload.fxCache,
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

    final resolved = _resolvePrice(asset, prices, payload.settings.priceTtl, now);
    Money? value;
    if (resolved != null) {
      try {
        value = convertMoney(resolved.price.times(quantity), base, rates);
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
      priced: resolved != null,
      priceAsOf: resolved?.asOf,
      stale: resolved?.stale ?? false,
    ));
  }

  return PortfolioView(
    base: base,
    rows: rows,
    totalValue: totalValue,
    totalCostBasis: totalCost,
  );
}
