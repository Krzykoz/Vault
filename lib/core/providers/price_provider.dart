import '../model/asset.dart';
import '../model/money.dart';

/// A price for a symbol at a point in time, in the currency the provider reports.
class PriceQuote {
  final Money price;
  final DateTime asOf;

  const PriceQuote(this.price, this.asOf);
}

/// Thrown when a price cannot be obtained (unknown symbol, network/HTTP error,
/// or an unparseable response). The UI can fall back to manual entry.
class PriceUnavailable implements Exception {
  final String reason;

  const PriceUnavailable(this.reason);

  @override
  String toString() => 'PriceUnavailable: $reason';
}

/// A pluggable source of prices. New providers are added by implementing this
/// interface and registering them — no existing provider is edited (Open/Closed).
abstract interface class PriceProvider {
  /// Stable identifier stored alongside cached prices.
  String get id;

  /// Whether this provider can price [asset].
  bool supports(Asset asset);

  /// Fetches the latest quote for [symbol]. Throws [PriceUnavailable] on failure.
  Future<PriceQuote> fetchQuote(String symbol);
}
