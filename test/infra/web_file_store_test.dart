import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/infra/web_file_store.dart';

void main() {
  group('WebFileStore', () {
    test('read returns null until a file is loaded', () async {
      final store = WebFileStore(pick: () async => null, download: (_, _) {});
      expect(await store.read(), isNull);
    });

    test('write keeps the bytes and triggers a download', () async {
      Uint8List? downloaded;
      String? name;
      final store = WebFileStore(
        pick: () async => null,
        download: (bytes, filename) {
          downloaded = bytes;
          name = filename;
        },
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      await store.write(bytes);
      expect(await store.read(), bytes);
      expect(downloaded, bytes);
      expect(name, 'vault.vlt');
    });

    test('pickInto loads the chosen file', () async {
      final picked = Uint8List.fromList([9, 9]);
      final store =
          WebFileStore(pick: () async => picked, download: (_, _) {});
      expect(await store.pickInto(), isTrue);
      expect(await store.read(), picked);
    });

    test('pickInto returns false when cancelled', () async {
      final store = WebFileStore(pick: () async => null, download: (_, _) {});
      expect(await store.pickInto(), isFalse);
      expect(await store.read(), isNull);
    });
  });
}
