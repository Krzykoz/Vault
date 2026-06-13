import '../cache/fx_cache.dart';
import '../cache/price_cache.dart';
import 'asset.dart';
import 'lot.dart';
import 'settings.dart';

/// The full decrypted contents of a vault: settings, the user's assets and
/// purchase lots, and the cached prices/FX rates so the app works offline.
class VaultPayload {
  final Settings settings;
  final List<Asset> assets;
  final List<Lot> lots;
  final PriceCache priceCache;
  final FxCache fxCache;

  VaultPayload({
    required this.settings,
    this.assets = const [],
    this.lots = const [],
    PriceCache? priceCache,
    FxCache? fxCache,
  })  : priceCache = priceCache ?? PriceCache(),
        fxCache = fxCache ?? FxCache();

  VaultPayload copyWith({
    Settings? settings,
    List<Asset>? assets,
    List<Lot>? lots,
    PriceCache? priceCache,
    FxCache? fxCache,
  }) {
    return VaultPayload(
      settings: settings ?? this.settings,
      assets: assets ?? this.assets,
      lots: lots ?? this.lots,
      priceCache: priceCache ?? this.priceCache,
      fxCache: fxCache ?? this.fxCache,
    );
  }

  Map<String, dynamic> toMap() => {
        'settings': settings.toMap(),
        'assets': [for (final a in assets) a.toMap()],
        'lots': [for (final l in lots) l.toMap()],
        'priceCache': priceCache.toMaps(),
        'fxCache': fxCache.toMaps(),
      };

  factory VaultPayload.fromMap(Map<String, dynamic> map) => VaultPayload(
        settings:
            Settings.fromMap((map['settings'] as Map).cast<String, dynamic>()),
        assets: [
          for (final e in (map['assets'] as List? ?? const []))
            Asset.fromMap((e as Map).cast<String, dynamic>()),
        ],
        lots: [
          for (final e in (map['lots'] as List? ?? const []))
            Lot.fromMap((e as Map).cast<String, dynamic>()),
        ],
        priceCache: PriceCache.fromMaps(map['priceCache'] as List? ?? const []),
        fxCache: FxCache.fromMaps(map['fxCache'] as List? ?? const []),
      );
}
