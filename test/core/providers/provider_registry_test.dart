import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/providers/price_provider.dart';
import 'package:vault/core/providers/provider_registry.dart';
import 'package:vault/core/providers/yahoo_finance_provider.dart';

import '../../support/fakes.dart';

/// A second provider that covers an asset type Yahoo does NOT — added without
/// touching the Yahoo provider (Open/Closed).
class _CashProvider implements PriceProvider {
  @override
  String get id => 'cash-bank';

  @override
  bool supports(Asset asset) => asset.type == AssetType.cash;

  @override
  Future<PriceQuote> fetchQuote(String symbol) async =>
      throw const PriceUnavailable('not supported');
}

void main() {
  final usd = Currency('USD');

  Asset asset(AssetType type, {String? symbol}) => Asset(
        id: 'a',
        type: type,
        name: 'X',
        nativeCurrency: usd,
        symbol: symbol,
      );

  test('selects the first provider that supports the asset', () {
    final registry = ProviderRegistry([
      YahooFinanceProvider(FakeHttpClient()),
      _CashProvider(),
    ]);

    expect(
      registry.providerFor(asset(AssetType.stock, symbol: 'AAPL'))!.id,
      'yahoo',
    );
    // A new provider extends coverage to cash without editing Yahoo.
    expect(registry.providerFor(asset(AssetType.cash))!.id, 'cash-bank');
  });

  test('returns null when nothing supports the asset', () {
    final registry = ProviderRegistry([YahooFinanceProvider(FakeHttpClient())]);
    expect(registry.providerFor(asset(AssetType.manual)), isNull);
  });

  test('register adds a provider', () {
    final registry = ProviderRegistry();
    expect(registry.providerFor(asset(AssetType.cash)), isNull);
    registry.register(_CashProvider());
    expect(registry.providerFor(asset(AssetType.cash))!.id, 'cash-bank');
  });
}
