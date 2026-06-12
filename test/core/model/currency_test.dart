import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/model/currency.dart';

void main() {
  group('Currency', () {
    test('uppercases and trims the code', () {
      expect(Currency(' usd ').code, 'USD');
    });

    test('rejects empty codes', () {
      expect(() => Currency('   '), throwsArgumentError);
    });

    test('value equality', () {
      expect(Currency('eur'), Currency('EUR'));
      expect(Currency('eur').hashCode, Currency('EUR').hashCode);
      expect(Currency('usd') == Currency('eur'), isFalse);
    });

    test('toString is the code', () {
      expect(Currency('gbp').toString(), 'GBP');
    });

    test('map round-trip normalizes the code', () {
      expect(Currency.fromMap(Currency(' usd ').toMap()), Currency('USD'));
    });
  });
}
