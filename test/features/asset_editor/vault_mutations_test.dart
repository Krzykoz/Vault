import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/lot.dart';
import 'package:vault/core/model/money.dart';
import 'package:vault/core/vault_repository.dart';
import 'package:vault/features/unlock/vault_controller.dart';

import '../../support/fakes.dart';

/// An in-memory store whose writes take a beat, so a lock can land mid-write.
class _SlowStore extends InMemoryFileStore {
  @override
  Future<void> write(Uint8List data) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    await super.write(data);
  }
}

void main() {
  final usd = Currency('USD');

  ProviderContainer containerWith(InMemoryFileStore store) {
    final container = ProviderContainer(
      overrides: [
        vaultFileStoreProvider.overrideWithValue(store),
        vaultCreateParamsProvider
            .overrideWithValue(const Argon2Params.forTesting()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Lot lot() => Lot(
        id: 'l',
        assetId: 'a',
        quantity: Decimal.fromInt(2),
        unitCost: Money.parse('100', usd),
        date: DateTime.utc(2024, 1, 1),
      );

  Asset apple() => Asset(
        id: 'a',
        type: AssetType.stock,
        name: 'Apple',
        nativeCurrency: usd,
        symbol: 'AAPL',
      );

  test('upserting and deleting assets and lots persists to the file', () async {
    final store = InMemoryFileStore();
    final container = containerWith(store);
    final controller = container.read(vaultControllerProvider.notifier);
    // Let the initial existence check settle before creating.
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await controller.create(password: 'pw');
    expect(container.read(vaultControllerProvider).phase, VaultPhase.open);

    await controller.upsertAsset(apple());
    await controller.upsertLot(lot());

    final state = container.read(vaultControllerProvider);
    expect(state.payload!.assets, hasLength(1));
    expect(state.payload!.lots, hasLength(1));

    // Persisted: a fresh repository can reopen and see them.
    final reopened = await VaultRepository(store).open(password: 'pw');
    expect(reopened.assets.single.name, 'Apple');
    expect(reopened.lots.single.quantity, Decimal.fromInt(2));
  });

  test('upsert with an existing id replaces rather than duplicates', () async {
    final container = containerWith(InMemoryFileStore());
    final controller = container.read(vaultControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await controller.create(password: 'pw');

    await controller.upsertAsset(apple());
    await controller.upsertAsset(apple().copyWith(name: 'Apple Inc.'));

    final assets = container.read(vaultControllerProvider).payload!.assets;
    expect(assets, hasLength(1));
    expect(assets.single.name, 'Apple Inc.');
  });

  test('deleting an asset cascades to its lots', () async {
    final container = containerWith(InMemoryFileStore());
    final controller = container.read(vaultControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await controller.create(password: 'pw');
    await controller.upsertAsset(apple());
    await controller.upsertLot(lot());

    await controller.deleteAsset('a');

    final payload = container.read(vaultControllerProvider).payload!;
    expect(payload.assets, isEmpty);
    expect(payload.lots, isEmpty);
  });

  test('deleting a single lot leaves the asset intact', () async {
    final container = containerWith(InMemoryFileStore());
    final controller = container.read(vaultControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await controller.create(password: 'pw');
    await controller.upsertAsset(apple());
    await controller.upsertLot(lot());

    await controller.deleteLot('l');

    final payload = container.read(vaultControllerProvider).payload!;
    expect(payload.assets, hasLength(1));
    expect(payload.lots, isEmpty);
  });

  test('a write completing after lock does not reopen the vault', () async {
    final store = _SlowStore();
    final container = containerWith(store);
    final controller = container.read(vaultControllerProvider.notifier);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await controller.create(password: 'pw');
    expect(container.read(vaultControllerProvider).phase, VaultPhase.open);

    final pending = controller.upsertAsset(apple()); // slow write in flight
    controller.lock(); // lock before it finishes
    expect(container.read(vaultControllerProvider).phase, VaultPhase.locked);

    await pending; // let the write complete
    expect(container.read(vaultControllerProvider).phase, VaultPhase.locked);
    // The repository must also stay closed: no decrypted payload in memory.
    final repo = container.read(vaultRepositoryProvider);
    expect(repo.isOpen, isFalse);
    expect(() => repo.payload, throwsStateError);
  });
}
