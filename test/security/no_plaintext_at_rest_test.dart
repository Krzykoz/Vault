import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/crypto/kdf.dart';
import 'package:vault/core/model/asset.dart';
import 'package:vault/core/model/currency.dart';
import 'package:vault/core/model/payload.dart';
import 'package:vault/core/model/settings.dart';
import 'package:vault/core/vault_repository.dart';

import '../support/fakes.dart';

/// Privacy invariant: everything the user enters is encrypted before it touches
/// the backing store. Nothing identifiable should be readable in the file.
void main() {
  test('saved vault bytes contain no plaintext from the portfolio', () async {
    final store = InMemoryFileStore();
    final repo =
        VaultRepository(store, createParams: const Argon2Params.forTesting());

    const secretName = 'PLAINTEXT_ASSET_NAME_SHOULD_NOT_LEAK';
    const secretSymbol = 'TOPSECRETSYM';
    const password = 'correct horse battery staple';

    await repo.create(
      password: password,
      initial: VaultPayload(
        settings: Settings(baseCurrency: Currency('USD')),
        assets: [
          Asset(
            id: 'a1',
            type: AssetType.stock,
            name: secretName,
            nativeCurrency: Currency('USD'),
            symbol: secretSymbol,
          ),
        ],
      ),
    );

    final bytes = store.bytes;
    expect(bytes, isNotNull, reason: 'the vault should have been written');

    final haystack = utf8.decode(bytes!, allowMalformed: true);
    expect(haystack.contains(secretName), isFalse,
        reason: 'asset name leaked in plaintext');
    expect(haystack.contains(secretSymbol), isFalse,
        reason: 'symbol leaked in plaintext');
    expect(haystack.contains(password), isFalse,
        reason: 'password leaked in plaintext');

    // Sanity: we really are scanning a Vault envelope (its magic is in there).
    expect(haystack.contains('VLT1'), isTrue);
  });
}
