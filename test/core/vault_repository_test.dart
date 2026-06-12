import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/aead.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/model/payload.dart';
import 'package:vault/core/model/settings.dart';
import 'package:vault/core/vault_repository.dart';

import '../support/fakes.dart';

/// In-memory store whose writes take a beat, so close() can land mid-write.
class _SlowStore extends InMemoryFileStore {
  @override
  Future<void> write(Uint8List data) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await super.write(data);
  }
}

void main() {
  final usd = Currency('USD');
  const params = Argon2Params.forTesting();

  VaultRepository repoFor(InMemoryFileStore store) =>
      VaultRepository(store, createParams: params);

  VaultPayload sample() => VaultPayload(
        settings: Settings(baseCurrency: usd),
        assets: [
          Asset(
            id: 'a',
            type: AssetType.stock,
            name: 'TOPSECRETPOSITION',
            nativeCurrency: usd,
            symbol: 'AAPL',
          ),
        ],
        lots: [
          Lot(
            id: 'l',
            assetId: 'a',
            quantity: Decimal.fromInt(2),
            unitCost: Money.parse('100', usd),
            date: DateTime.utc(2024, 1, 1),
          ),
        ],
      );

  group('VaultRepository', () {
    test('exists() is false until a vault is created', () async {
      final store = InMemoryFileStore();
      final repo = repoFor(store);
      expect(await repo.exists(), isFalse);
      await repo.create(password: 'pw', initial: sample());
      expect(await repo.exists(), isTrue);
    });

    test('create then open round-trips the payload', () async {
      final store = InMemoryFileStore();
      await repoFor(store).create(password: 'pw', initial: sample());

      final reopened = repoFor(store);
      final payload = await reopened.open(password: 'pw');
      expect(payload.toMap(), sample().toMap());
      expect(reopened.isOpen, isTrue);
    });

    test('update persists changes that survive a reopen', () async {
      final store = InMemoryFileStore();
      final repo = repoFor(store);
      await repo.create(password: 'pw', initial: sample());

      await repo.update((current) => current.copyWith(
            assets: [
              ...current.assets,
              Asset(
                id: 'b',
                type: AssetType.crypto,
                name: 'Bitcoin',
                nativeCurrency: usd,
                symbol: 'BTC',
              ),
            ],
          ));

      final reopened = await repoFor(store).open(password: 'pw');
      expect(reopened.assets.map((a) => a.id), containsAll(['a', 'b']));
    });

    test('each save produces fresh bytes but decodes the same', () async {
      final store = InMemoryFileStore();
      final repo = repoFor(store);
      await repo.create(password: 'pw', initial: sample());
      final before = List<int>.from(store.bytes!);

      await repo.save(repo.payload); // re-save identical payload

      expect(store.bytes, isNot(before)); // fresh nonce each write
      final reopened = await repoFor(store).open(password: 'pw');
      expect(reopened.toMap(), sample().toMap());
    });

    test('the written file contains no plaintext holdings', () async {
      final store = InMemoryFileStore();
      await repoFor(store).create(password: 'pw', initial: sample());
      final asText = utf8.decode(store.bytes!, allowMalformed: true);
      expect(asText.contains('TOPSECRETPOSITION'), isFalse);
      expect(asText.contains('AAPL'), isFalse);
    });

    test('open with the wrong password throws WrongPassword', () async {
      final store = InMemoryFileStore();
      await repoFor(store).create(password: 'right', initial: sample());
      expect(
        () => repoFor(store).open(password: 'wrong'),
        throwsA(isA<WrongPassword>()),
      );
    });

    test('open without a file throws VaultNotFound', () async {
      expect(
        () => repoFor(InMemoryFileStore()).open(password: 'pw'),
        throwsA(isA<VaultNotFound>()),
      );
    });

    test('reading payload before opening throws StateError', () {
      expect(() => repoFor(InMemoryFileStore()).payload, throwsStateError);
    });

    test('save before opening throws StateError', () {
      expect(
        () => repoFor(InMemoryFileStore()).save(sample()),
        throwsStateError,
      );
    });

    test('a save finishing after close does not restore the session', () async {
      final repo = VaultRepository(_SlowStore(), createParams: params);
      await repo.create(password: 'pw', initial: sample());

      final pending = repo.save(sample()); // slow write in flight
      repo.close();
      await pending;

      expect(repo.isOpen, isFalse);
      expect(() => repo.payload, throwsStateError);
    });
  });
}
