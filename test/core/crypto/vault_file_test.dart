import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/aead.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/core/crypto/vault_file.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/model/payload.dart';
import 'package:vault/core/model/settings.dart';

void main() {
  final usd = Currency('USD');
  final eur = Currency('EUR');
  const params = Argon2Params.forTesting();
  final codec = VaultCodec();

  VaultPayload sample() => VaultPayload(
        settings:
            Settings(baseCurrency: usd, priceTtl: const Duration(minutes: 15)),
        assets: [
          Asset(
            id: 'a',
            type: AssetType.stock,
            name: 'Apple',
            nativeCurrency: usd,
            symbol: 'AAPL',
          ),
          Asset(
            id: 'b',
            type: AssetType.crypto,
            name: 'Bitcoin',
            nativeCurrency: eur,
            symbol: 'BTC',
          ),
        ],
        lots: [
          Lot(
            id: 'l1',
            assetId: 'a',
            quantity: Decimal.fromInt(3),
            unitCost: Money.parse('100.50', usd),
            date: DateTime.utc(2023, 5, 1),
          ),
          Lot(
            id: 'l2',
            assetId: 'b',
            quantity: Decimal.parse('0.25'),
            unitCost: Money.parse('20000', eur),
            date: DateTime.utc(2024, 2, 2),
          ),
        ],
      );

  group('VaultCodec', () {
    test('encrypt/decrypt round-trips the payload', () async {
      final bytes = await codec.encode(
        payload: sample(),
        password: 'correct horse',
        params: params,
      );
      final decoded = await codec.decode(bytes: bytes, password: 'correct horse');
      expect(decoded.toMap(), sample().toMap());
    });

    test('same payload encodes differently but decodes identically', () async {
      final a = await codec.encode(payload: sample(), password: 'pw', params: params);
      final b = await codec.encode(payload: sample(), password: 'pw', params: params);
      expect(a, isNot(b)); // random salt + nonce per write
      final da = await codec.decode(bytes: a, password: 'pw');
      final db = await codec.decode(bytes: b, password: 'pw');
      expect(da.toMap(), db.toMap());
    });

    test('the wrong password throws WrongPassword', () async {
      final bytes = await codec.encode(payload: sample(), password: 'right', params: params);
      expect(
        () => codec.decode(bytes: bytes, password: 'wrong'),
        throwsA(isA<WrongPassword>()),
      );
    });

    test('tampered bytes throw WrongPassword', () async {
      final bytes = await codec.encode(payload: sample(), password: 'pw', params: params);
      final tampered = Uint8List.fromList(bytes);
      tampered[tampered.length - 1] ^= 0xFF; // flip a byte of the mac
      expect(
        () => codec.decode(bytes: tampered, password: 'pw'),
        throwsA(isA<WrongPassword>()),
      );
    });

    test('garbage or empty bytes throw InvalidVaultFile', () async {
      expect(
        () => codec.decode(bytes: const [0, 1, 2, 3], password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
      expect(
        () => codec.decode(bytes: const [], password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
    });

    test('bad magic throws InvalidVaultFile', () async {
      final bytes = cborEncode(CborValue({'magic': 'NOPE', 'version': 1}));
      expect(
        () => codec.decode(bytes: bytes, password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
    });

    test('unsupported version throws InvalidVaultFile', () async {
      final bytes = cborEncode(CborValue({'magic': 'VLT1', 'version': 999}));
      expect(
        () => codec.decode(bytes: bytes, password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
    });

    test('malformed kdf params throw InvalidVaultFile, not a TypeError', () async {
      final bytes =
          cborEncode(CborValue({'magic': 'VLT1', 'version': 1, 'kdf': {}}));
      expect(
        () => codec.decode(bytes: bytes, password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
    });

    test('out-of-range kdf params are rejected without deriving a key', () async {
      final bytes = cborEncode(CborValue({
        'magic': 'VLT1',
        'version': 1,
        'kdf': {
          'parallelism': 1,
          'memory': 2000000000, // absurd; must be rejected, not attempted
          'iterations': 1,
          'hashLength': 32,
        },
      }));
      expect(
        () => codec.decode(bytes: bytes, password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
    });

    test('an unsupported hash length is rejected', () async {
      final bytes = cborEncode(CborValue({
        'magic': 'VLT1',
        'version': 1,
        'kdf': {
          'parallelism': 1,
          'memory': 256,
          'iterations': 1,
          'hashLength': 16,
        },
      }));
      expect(
        () => codec.decode(bytes: bytes, password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
    });

    test('a file missing required fields throws InvalidVaultFile', () async {
      final bytes = cborEncode(CborValue({
        'magic': 'VLT1',
        'version': 1,
        'kdf': {
          'parallelism': 1,
          'memory': 256,
          'iterations': 1,
          'hashLength': 32,
        },
        // salt/nonce/ct/mac omitted
      }));
      expect(
        () => codec.decode(bytes: bytes, password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
    });

    test('a non-int byte field throws InvalidVaultFile', () async {
      final bytes = cborEncode(CborValue({
        'magic': 'VLT1',
        'version': 1,
        'kdf': {
          'parallelism': 1,
          'memory': 256,
          'iterations': 1,
          'hashLength': 32,
        },
        'salt': ['x'], // not bytes
      }));
      expect(
        () => codec.decode(bytes: bytes, password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
    });

    test('an out-of-range byte value throws InvalidVaultFile', () async {
      final bytes = cborEncode(CborValue({
        'magic': 'VLT1',
        'version': 1,
        'kdf': {
          'parallelism': 1,
          'memory': 256,
          'iterations': 1,
          'hashLength': 32,
        },
        'salt': [999], // not a valid byte
      }));
      expect(
        () => codec.decode(bytes: bytes, password: 'pw'),
        throwsA(isA<InvalidVaultFile>()),
      );
    });
  });
}
