import 'package:decimal/decimal.dart';

import '../model/currency.dart';

/// An FX rate for a currency pair. [date] is the value date requested (null for
/// the latest spot rate); [asOf] is when the data applies.
class FxQuote {
  final Decimal rate;
  final DateTime asOf;
  final DateTime? date;

  const FxQuote({required this.rate, required this.asOf, this.date});
}

/// A pluggable source of FX rates, separate from price quotes so providers can
/// implement one, the other, or both.
abstract interface class FxProvider {
  /// Rate to convert one unit of [base] into [quote], for [date] (null = latest).
  /// Throws [PriceUnavailable] (from price_provider.dart) on failure.
  Future<FxQuote> fetchRate(Currency base, Currency quote, {DateTime? date});
}
