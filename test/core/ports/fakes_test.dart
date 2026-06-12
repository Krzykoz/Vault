import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vault/core/ports/http_client.dart';

import '../../support/fakes.dart';

void main() {
  group('FixedClock', () {
    test('returns the set time', () {
      final time = DateTime.utc(2024, 6, 1, 12);
      expect(FixedClock(time).now(), time);
    });
  });

  group('InMemorySecureStore', () {
    test('writes, reads, and deletes', () async {
      final store = InMemorySecureStore();
      expect(await store.read('k'), isNull);
      await store.write('k', 'secret');
      expect(await store.read('k'), 'secret');
      await store.delete('k');
      expect(await store.read('k'), isNull);
    });
  });

  group('InMemoryFileStore', () {
    test('round-trips bytes and starts empty', () async {
      final store = InMemoryFileStore();
      expect(await store.read(), isNull);
      await store.write(Uint8List.fromList([1, 2, 3]));
      expect(await store.read(), [1, 2, 3]);
    });
  });

  group('FakeBiometricGate', () {
    test('reports availability and counts auth attempts', () async {
      final gate = FakeBiometricGate(available: false, willSucceed: false);
      expect(await gate.isAvailable(), isFalse);
      expect(await gate.authenticate(reason: 'unlock'), isFalse);
      expect(gate.authCalls, 1);
    });
  });

  group('FakeHttpClient', () {
    test('returns canned responses and records requests', () async {
      final url = Uri.parse('https://example.com/quote');
      final client = FakeHttpClient({
        url.toString(): const HttpResponse(200, 'ok'),
      });
      final response = await client.get(url);
      expect(response.statusCode, 200);
      expect(response.isOk, isTrue);
      expect(client.requested, [url]);
    });

    test('returns 404 for an unknown url', () async {
      final response = await FakeHttpClient().get(Uri.parse('https://x.test'));
      expect(response.statusCode, 404);
      expect(response.isOk, isFalse);
    });
  });
}
