import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../core/model/money.dart';

/// Formats [money] for display in [locale] (e.g. "$1,234.50", "1.234,50 €",
/// "¥1,235"). Display only: the value is rounded to the currency's usual number
/// of digits just for presentation — stored amounts stay exact [Decimal]s.
String formatMoney(Money? money, {String? locale, String placeholder = '—'}) {
  if (money == null) return placeholder;
  final format =
      NumberFormat.simpleCurrency(locale: locale, name: money.currency.code);
  final digits = format.decimalDigits ?? 2;
  final rounded = money.amount.round(scale: digits);
  return format.format(rounded.toDouble());
}

/// Formats a signed percentage like "+12.34%" or "-1.20%", exact to two places.
String formatPercent(Decimal percent) {
  final text = percent.toStringAsFixed(2);
  return text.startsWith('-') ? '$text%' : '+$text%';
}
