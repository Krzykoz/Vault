import 'currency.dart';

/// User-level settings stored inside the encrypted vault. The base currency can
/// change at any time; TTLs decide when cached prices/FX rates are stale.
class Settings {
  final Currency baseCurrency;
  final Duration priceTtl;
  final Duration fxTtl;

  const Settings({
    required this.baseCurrency,
    this.priceTtl = const Duration(hours: 1),
    this.fxTtl = const Duration(hours: 12),
  });

  Settings copyWith({
    Currency? baseCurrency,
    Duration? priceTtl,
    Duration? fxTtl,
  }) {
    return Settings(
      baseCurrency: baseCurrency ?? this.baseCurrency,
      priceTtl: priceTtl ?? this.priceTtl,
      fxTtl: fxTtl ?? this.fxTtl,
    );
  }

  Map<String, dynamic> toMap() => {
        'baseCurrency': baseCurrency.code,
        'priceTtlSeconds': priceTtl.inSeconds,
        'fxTtlSeconds': fxTtl.inSeconds,
      };

  factory Settings.fromMap(Map<String, dynamic> map) => Settings(
        baseCurrency: Currency(map['baseCurrency'] as String),
        priceTtl: Duration(seconds: map['priceTtlSeconds'] as int),
        fxTtl: Duration(seconds: map['fxTtlSeconds'] as int),
      );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.baseCurrency == baseCurrency &&
      other.priceTtl == priceTtl &&
      other.fxTtl == fxTtl;

  @override
  int get hashCode => Object.hash(baseCurrency, priceTtl, fxTtl);

  @override
  String toString() => 'Settings(base=$baseCurrency)';
}
