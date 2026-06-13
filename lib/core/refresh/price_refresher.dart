import '../cache/fx_cache.dart';
import '../cache/price_cache.dart';
import '../model/currency.dart';
import '../model/payload.dart';
import '../providers/fx_provider.dart';
import '../providers/price_provider.dart';
import '../providers/provider_registry.dart';

/// The updated caches after a refresh, plus any symbols/pairs that failed.
class RefreshResult {
  final PriceCache priceCache;
  final FxCache fxCache;
  final List<String> failures;

  const RefreshResult({
    required this.priceCache,
    required this.fxCache,
    this.failures = const [],
  });

  bool get hadFailures => failures.isNotEmpty;
}

/// Fetches the prices and FX rates a portfolio needs and folds them into the
/// caches. Assets with a manual price are skipped (the manual price wins). All
/// network failures are collected rather than thrown, so a partial refresh still
/// updates what it could.
class PriceRefresher {
  final ProviderRegistry registry;
  final FxProvider fxProvider;

  const PriceRefresher(this.registry, this.fxProvider);

  Future<RefreshResult> refresh(
    VaultPayload payload, {
    required DateTime now,
  }) async {
    var prices = payload.priceCache;
    var fx = payload.fxCache;
    final failures = <String>[];
    final base = payload.settings.baseCurrency;

    // 1. Latest quotes for priced assets without a manual price.
    for (final asset in payload.assets) {
      final symbol = asset.symbol;
      if (asset.manualPrice != null || symbol == null || symbol.isEmpty) continue;
      final provider = registry.providerFor(asset);
      if (provider == null) continue;
      try {
        final quote = await provider.fetchQuote(symbol);
        prices = prices.put(PriceCacheEntry(
          providerId: provider.id,
          symbol: symbol,
          price: quote.price,
          fetchedAt: now,
        ));
        fx = await _ensureLatestFx(fx, quote.price.currency, base, now, failures);
      } on PriceUnavailable {
        failures.add(symbol);
      }
    }

    // 2. Latest FX for each asset's native currency -> base.
    for (final asset in payload.assets) {
      fx = await _ensureLatestFx(fx, asset.nativeCurrency, base, now, failures);
    }

    // 3. Historical FX for each lot's currency -> base on its purchase date.
    for (final lot in payload.lots) {
      final currency = lot.unitCost.currency;
      if (currency == base) continue;
      if (fx.dated(currency, base, lot.date) != null) continue;
      try {
        final quote = await fxProvider.fetchRate(currency, base, date: lot.date);
        fx = fx.put(FxRateEntry(
          base: currency,
          quote: base,
          rate: quote.rate,
          fetchedAt: now,
          date: lot.date,
        ));
      } on PriceUnavailable {
        failures.add('${currency.code}->${base.code}@${lot.date.toIso8601String()}');
      }
    }

    return RefreshResult(priceCache: prices, fxCache: fx, failures: failures);
  }

  Future<FxCache> _ensureLatestFx(
    FxCache fx,
    Currency from,
    Currency to,
    DateTime now,
    List<String> failures,
  ) async {
    if (from == to) return fx;
    try {
      final quote = await fxProvider.fetchRate(from, to);
      return fx.put(FxRateEntry(
        base: from,
        quote: to,
        rate: quote.rate,
        fetchedAt: now,
      ));
    } on PriceUnavailable {
      failures.add('${from.code}->${to.code}');
      return fx;
    }
  }
}
