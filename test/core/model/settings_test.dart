import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/settings.dart';

void main() {
  group('Settings', () {
    test('sensible TTL defaults', () {
      final s = Settings(baseCurrency: Currency('USD'));
      expect(s.priceTtl, const Duration(hours: 1));
      expect(s.fxTtl, const Duration(hours: 12));
    });

    test('copyWith overrides only the given fields', () {
      final s = Settings(baseCurrency: Currency('USD'))
          .copyWith(baseCurrency: Currency('EUR'));
      expect(s.baseCurrency, Currency('EUR'));
      expect(s.priceTtl, const Duration(hours: 1));
    });

    test('map round-trip', () {
      final s = Settings(
        baseCurrency: Currency('PLN'),
        priceTtl: const Duration(minutes: 30),
        fxTtl: const Duration(hours: 6),
      );
      expect(Settings.fromMap(s.toMap()), s);
    });
  });
}
