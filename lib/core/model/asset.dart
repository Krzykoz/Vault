import 'currency.dart';
import 'money.dart';

/// What kind of holding an [Asset] represents.
///
/// `manual` covers anything priced by hand (real estate, collectibles, etc.).
enum AssetType { stock, etf, crypto, commodity, cash, manual }

/// Something the user owns. Priced assets carry a [symbol] used to look up a
/// quote; `cash`/`manual` assets may instead rely on [manualPrice].
class Asset {
  final String id;
  final AssetType type;
  final String? symbol;
  final String name;
  final Currency nativeCurrency;
  final Money? manualPrice;

  const Asset({
    required this.id,
    required this.type,
    required this.name,
    required this.nativeCurrency,
    this.symbol,
    this.manualPrice,
  });

  /// True when this asset can be looked up by symbol from a price provider.
  bool get isPriced => symbol != null && symbol!.isNotEmpty;

  Asset copyWith({
    String? id,
    AssetType? type,
    String? symbol,
    String? name,
    Currency? nativeCurrency,
    Money? manualPrice,
  }) {
    return Asset(
      id: id ?? this.id,
      type: type ?? this.type,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      nativeCurrency: nativeCurrency ?? this.nativeCurrency,
      manualPrice: manualPrice ?? this.manualPrice,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'symbol': symbol,
        'name': name,
        'nativeCurrency': nativeCurrency.code,
        'manualPrice': manualPrice?.toMap(),
      };

  factory Asset.fromMap(Map<String, dynamic> map) => Asset(
        id: map['id'] as String,
        type: AssetType.values.byName(map['type'] as String),
        symbol: map['symbol'] as String?,
        name: map['name'] as String,
        nativeCurrency: Currency(map['nativeCurrency'] as String),
        manualPrice: map['manualPrice'] == null
            ? null
            : Money.fromMap((map['manualPrice'] as Map).cast<String, dynamic>()),
      );

  @override
  bool operator ==(Object other) =>
      other is Asset &&
      other.id == id &&
      other.type == type &&
      other.symbol == symbol &&
      other.name == name &&
      other.nativeCurrency == nativeCurrency &&
      other.manualPrice == manualPrice;

  @override
  int get hashCode =>
      Object.hash(id, type, symbol, name, nativeCurrency, manualPrice);

  @override
  String toString() => 'Asset($id, ${type.name}, $name)';
}
