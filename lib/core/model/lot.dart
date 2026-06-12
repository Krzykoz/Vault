import 'package:decimal/decimal.dart';

import 'money.dart';

/// A single purchase of an [Asset]. The same asset can have many lots bought at
/// different prices and dates, which is what lets cost basis use the
/// purchase-date FX rate later.
class Lot {
  final String id;
  final String assetId;
  final Decimal quantity;
  final Money unitCost;
  final DateTime date;
  final Money? fee;

  const Lot({
    required this.id,
    required this.assetId,
    required this.quantity,
    required this.unitCost,
    required this.date,
    this.fee,
  });

  /// Total cost of this lot in its own currency: `unitCost * quantity` plus any
  /// [fee]. Throws if the fee is in a different currency than the unit cost.
  Money get cost {
    final base = unitCost.times(quantity);
    return fee == null ? base : base + fee!;
  }

  Lot copyWith({
    String? id,
    String? assetId,
    Decimal? quantity,
    Money? unitCost,
    DateTime? date,
    Money? fee,
  }) {
    return Lot(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      date: date ?? this.date,
      fee: fee ?? this.fee,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'assetId': assetId,
        'quantity': quantity.toString(),
        'unitCost': unitCost.toMap(),
        'date': date.toUtc().toIso8601String(),
        'fee': fee?.toMap(),
      };

  factory Lot.fromMap(Map<String, dynamic> map) => Lot(
        id: map['id'] as String,
        assetId: map['assetId'] as String,
        quantity: Decimal.parse(map['quantity'] as String),
        unitCost: Money.fromMap((map['unitCost'] as Map).cast<String, dynamic>()),
        date: DateTime.parse(map['date'] as String),
        fee: map['fee'] == null
            ? null
            : Money.fromMap((map['fee'] as Map).cast<String, dynamic>()),
      );

  @override
  bool operator ==(Object other) =>
      other is Lot &&
      other.id == id &&
      other.assetId == assetId &&
      other.quantity == quantity &&
      other.unitCost == unitCost &&
      other.date.isAtSameMomentAs(date) &&
      other.fee == fee;

  @override
  int get hashCode =>
      Object.hash(id, assetId, quantity, unitCost, date.toUtc(), fee);

  @override
  String toString() => 'Lot($id, asset=$assetId, qty=$quantity)';
}
