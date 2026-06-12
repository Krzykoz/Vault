import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/aead.dart';
import 'package:vault/core/crypto/secure_random.dart';

void main() {
  final aead = Aead();
  final key = secureRandomBytes(32);
  final plaintext = utf8.encode('top secret portfolio');

  group('Aead', () {
    test('round-trips plaintext', () async {
      final data = await aead.encrypt(key: key, plaintext: plaintext);
      final clear = await aead.decrypt(key: key, data: data);
      expect(clear, plaintext);
    });

    test('produces a 12-byte nonce and a 16-byte mac', () async {
      final data = await aead.encrypt(key: key, plaintext: plaintext);
      expect(data.nonce.length, 12);
      expect(data.mac.length, 16);
    });

    test('a fresh nonce is used on every call', () async {
      final a = await aead.encrypt(key: key, plaintext: plaintext);
      final b = await aead.encrypt(key: key, plaintext: plaintext);
      expect(a.nonce, isNot(b.nonce));
      expect(a.cipherText, isNot(b.cipherText));
    });

    test('a wrong key fails authentication', () async {
      final data = await aead.encrypt(key: key, plaintext: plaintext);
      final wrongKey = secureRandomBytes(32);
      expect(
        () => aead.decrypt(key: wrongKey, data: data),
        throwsA(isA<WrongPassword>()),
      );
    });

    test('tampered ciphertext is rejected', () async {
      final data = await aead.encrypt(key: key, plaintext: plaintext);
      final tampered = Uint8List.fromList(data.cipherText);
      tampered[0] ^= 0xFF;
      final bad = CipherData(
        nonce: data.nonce,
        cipherText: tampered,
        mac: data.mac,
      );
      expect(
        () => aead.decrypt(key: key, data: bad),
        throwsA(isA<WrongPassword>()),
      );
    });

    test('an aad mismatch is rejected', () async {
      final data = await aead.encrypt(
        key: key,
        plaintext: plaintext,
        aad: utf8.encode('version-1'),
      );
      expect(
        () => aead.decrypt(key: key, data: data, aad: utf8.encode('version-2')),
        throwsA(isA<WrongPassword>()),
      );
    });
  });
}
