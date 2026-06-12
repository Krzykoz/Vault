import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/kdf.dart';

void main() {
  const kdf = Kdf(Argon2Params.forTesting());
  final salt = List<int>.generate(16, (i) => i);

  group('Kdf', () {
    test('derives a key of the requested length', () async {
      final key = await kdf.deriveKey(password: 'hunter2', salt: salt);
      expect(key.length, 32);
    });

    test('is deterministic for the same password and salt', () async {
      final a = await kdf.deriveKey(password: 'hunter2', salt: salt);
      final b = await kdf.deriveKey(password: 'hunter2', salt: salt);
      expect(a, b);
    });

    test('a different password changes the key', () async {
      final a = await kdf.deriveKey(password: 'hunter2', salt: salt);
      final b = await kdf.deriveKey(password: 'hunter3', salt: salt);
      expect(a, isNot(b));
    });

    test('a different salt changes the key', () async {
      final a = await kdf.deriveKey(password: 'hunter2', salt: salt);
      final b = await kdf.deriveKey(
        password: 'hunter2',
        salt: List<int>.generate(16, (i) => i + 1),
      );
      expect(a, isNot(b));
    });

    test('parameters round-trip through a map', () {
      const params = Argon2Params();
      expect(Argon2Params.fromMap(params.toMap()), params);
    });
  });
}
