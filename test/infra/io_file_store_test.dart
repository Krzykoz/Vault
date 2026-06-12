import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/infra/io_file_store.dart';
import 'package:vault/infra/system_clock.dart';

void main() {
  group('SystemClock', () {
    test('returns UTC time', () {
      expect(const SystemClock().now().isUtc, isTrue);
    });
  });

  group('IoFileStore', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('vault_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('read returns null when the file does not exist', () async {
      final store = IoFileStore('${dir.path}/missing.vault');
      expect(await store.read(), isNull);
    });

    test('write then read round-trips bytes', () async {
      final store = IoFileStore('${dir.path}/portfolio.vault');
      final bytes = Uint8List.fromList([10, 20, 30, 40]);
      await store.write(bytes);
      expect(await store.read(), bytes);
    });

    test('write creates missing parent directories', () async {
      final store = IoFileStore('${dir.path}/nested/deep/portfolio.vault');
      await store.write(Uint8List.fromList([1]));
      expect(await store.read(), [1]);
    });
  });
}
