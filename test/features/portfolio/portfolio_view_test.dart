import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/model/payload.dart';
import 'package:vault/core/model/settings.dart';
import 'package:vault/features/portfolio/portfolio_view.dart';

void main() {
  final usd = Currency('USD');
  final eur = Currency('EUR');
  final now = DateTime.utc(2024, 6, 1);

  Lot lot(String id, String assetId, String qty, Money cost) => Lot(
        id: id,
        assetId: assetId,
        quantity: Decimal.parse(qty),
        unitCost: cost,
        date: DateTime.utc(2023, 1, 1),
      );

  test('values a manual-priced asset in the base currency', () {
    final payload = VaultPayload(
      settings: Settings(baseCurrency: usd),
      assets: [
        Asset(
          id: 'gold',
          type: AssetType.manual,
          name: 'Gold',
          nativeCurrency: usd,
          manualPrice: Money.parse('2000', usd),
        ),
      ],
      lots: [lot('l', 'gold', '2', Money.parse('1500', usd))],
    );

    final view = buildPortfolioView(payload, now: now);
    final row = view.rows.single;
    expect(row.quantity, Decimal.fromInt(2));
    expect(row.value, Money.parse('4000', usd));
    expect(row.costBasis, Money.parse('3000', usd));
    expect(row.gain, Money.parse('1000', usd));
    expect(row.gainPercent!.toDouble(), closeTo(33.33, 0.01));

    expect(view.totalValue, Money.parse('4000', usd));
    expect(view.totalCostBasis, Money.parse('3000', usd));
    expect(view.totalGain, Money.parse('1000', usd));
    expect(view.totalGainPercent!.toDouble(), closeTo(33.33, 0.01));
  });

  test('an unpriced asset shows cost but no value and is left out of the total',
      () {
    final payload = VaultPayload(
      settings: Settings(baseCurrency: usd),
      assets: [
        Asset(
          id: 'aapl',
          type: AssetType.stock,
          name: 'Apple',
          nativeCurrency: usd,
          symbol: 'AAPL',
        ),
      ],
      lots: [lot('l', 'aapl', '1', Money.parse('100', usd))],
    );

    final view = buildPortfolioView(payload, now: now);
    final row = view.rows.single;
    expect(row.priced, isFalse);
    expect(row.value, isNull);
    expect(row.costBasis, Money.parse('100', usd)); // base-currency cost is known
    expect(row.gain, isNull);

    // Cost without a value must not drag the total gain down.
    expect(view.totalValue, Money.zero(usd));
    expect(view.totalCostBasis, Money.zero(usd));
  });

  test('a foreign-currency asset with no FX cache cannot be valued', () {
    final payload = VaultPayload(
      settings: Settings(baseCurrency: usd),
      assets: [
        Asset(
          id: 'sap',
          type: AssetType.manual,
          name: 'SAP',
          nativeCurrency: eur,
          manualPrice: Money.parse('120', eur),
        ),
      ],
      lots: [lot('l', 'sap', '5', Money.parse('100', eur))],
    );

    final view = buildPortfolioView(payload, now: now);
    final row = view.rows.single;
    expect(row.priced, isTrue); // a manual price exists
    expect(row.value, isNull); // but EUR->USD is unavailable
    expect(row.costBasis, isNull);
  });

  test('an empty portfolio totals to zero with an undefined percentage', () {
    final payload = VaultPayload(settings: Settings(baseCurrency: usd));
    final view = buildPortfolioView(payload, now: now);
    expect(view.rows, isEmpty);
    expect(view.totalValue, Money.zero(usd));
    expect(view.totalGainPercent, isNull);
  });
}
