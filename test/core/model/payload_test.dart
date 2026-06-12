import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/model/payload.dart';
import 'package:vault/core/model/settings.dart';

void main() {
  final usd = Currency('USD');

  VaultPayload sample() => VaultPayload(
        settings: Settings(baseCurrency: usd),
        assets: [
          Asset(
            id: 'a',
            type: AssetType.stock,
            name: 'Apple',
            nativeCurrency: usd,
            symbol: 'AAPL',
          ),
        ],
        lots: [
          Lot(
            id: 'l',
            assetId: 'a',
            quantity: Decimal.fromInt(2),
            unitCost: Money.parse('100', usd),
            date: DateTime.utc(2024, 1, 1),
          ),
        ],
      );

  group('VaultPayload', () {
    test('map round-trip preserves settings, assets, and lots', () {
      final decoded = VaultPayload.fromMap(sample().toMap());
      expect(decoded.toMap(), sample().toMap());
      expect(decoded.assets.single.symbol, 'AAPL');
      expect(decoded.lots.single.cost, Money.parse('200', usd));
    });

    test('tolerates a payload with no assets or lots', () {
      final minimal = VaultPayload(settings: Settings(baseCurrency: usd));
      final decoded = VaultPayload.fromMap(minimal.toMap());
      expect(decoded.assets, isEmpty);
      expect(decoded.lots, isEmpty);
    });

    test('fromMap defaults missing asset/lot lists to empty', () {
      final decoded = VaultPayload.fromMap({
        'settings': Settings(baseCurrency: usd).toMap(),
      });
      expect(decoded.assets, isEmpty);
      expect(decoded.lots, isEmpty);
    });
  });
}
