import 'dart:typed_data';

import 'package:vault/core/ports/biometric_gate.dart';
import 'package:vault/core/ports/clock.dart';
import 'package:vault/core/ports/file_store.dart';
import 'package:vault/core/ports/http_client.dart';
import 'package:vault/core/ports/secure_store.dart';

/// A [Clock] returning a fixed, settable time.
class FixedClock implements Clock {
  DateTime current;

  FixedClock(this.current);

  @override
  DateTime now() => current;
}

/// In-memory [SecureStore] for tests.
class InMemorySecureStore implements SecureStore {
  final Map<String, String> entries = {};

  @override
  Future<void> write(String key, String value) async => entries[key] = value;

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> delete(String key) async => entries.remove(key);
}

/// In-memory [FileStore] for tests.
class InMemoryFileStore implements FileStore {
  Uint8List? bytes;

  InMemoryFileStore([this.bytes]);

  @override
  Future<Uint8List?> read() async => bytes;

  @override
  Future<void> write(Uint8List data) async => bytes = data;
}

/// A scriptable [BiometricGate] that records how often it was asked.
class FakeBiometricGate implements BiometricGate {
  bool available;
  bool willSucceed;
  int authCalls = 0;

  FakeBiometricGate({this.available = true, this.willSucceed = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate({required String reason}) async {
    authCalls++;
    return willSucceed;
  }
}

/// An [HttpClient] that returns canned responses keyed by URL and records every
/// request it received.
class FakeHttpClient implements HttpClient {
  final Map<String, HttpResponse> responses;
  final List<Uri> requested = [];

  FakeHttpClient([this.responses = const {}]);

  @override
  Future<HttpResponse> get(Uri url, {Map<String, String>? headers}) async {
    requested.add(url);
    return responses[url.toString()] ?? const HttpResponse(404, '');
  }
}
