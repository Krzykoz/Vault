import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/secure_random.dart';

void main() {
  group('secureRandomBytes', () {
    test('returns the requested length', () {
      expect(secureRandomBytes(16).length, 16);
      expect(secureRandomBytes(0).length, 0);
    });

    test('values are within byte range', () {
      final bytes = secureRandomBytes(64);
      expect(bytes.every((b) => b >= 0 && b <= 255), isTrue);
    });

    test('two draws differ', () {
      expect(secureRandomBytes(32), isNot(secureRandomBytes(32)));
    });
  });
}
