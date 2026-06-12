import 'asset.dart';
import 'lot.dart';
import 'settings.dart';

/// The full decrypted contents of a vault: settings plus the user's assets and
/// purchase lots. Price/FX caches are added in a later task; [fromMap] already
/// tolerates their absence so the format stays forward-compatible.
class VaultPayload {
  final Settings settings;
  final List<Asset> assets;
  final List<Lot> lots;

  const VaultPayload({
    required this.settings,
    this.assets = const [],
    this.lots = const [],
  });

  VaultPayload copyWith({
    Settings? settings,
    List<Asset>? assets,
    List<Lot>? lots,
  }) {
    return VaultPayload(
      settings: settings ?? this.settings,
      assets: assets ?? this.assets,
      lots: lots ?? this.lots,
    );
  }

  Map<String, dynamic> toMap() => {
        'settings': settings.toMap(),
        'assets': [for (final a in assets) a.toMap()],
        'lots': [for (final l in lots) l.toMap()],
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
      );
}
