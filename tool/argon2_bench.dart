// Standalone benchmark for Argon2id key-derivation cost across candidate
// parameter sets. Run on native with:
//
//   dart run tool/argon2_bench.dart
//
// The web/dart2wasm figure is the one that matters for unlock latency; see
// SPEC.md for how the production parameters were chosen.
import 'package:vault/core/crypto/kdf.dart';

const _candidates = <String, Argon2Params>{
  'm=8MiB  t=3 p=1':
      Argon2Params(memory: 8192, iterations: 3, parallelism: 1, hashLength: 32),
  'm=12MiB t=2 p=1':
      Argon2Params(memory: 12288, iterations: 2, parallelism: 1, hashLength: 32),
  'm=19MiB t=2 p=1 (OWASP)':
      Argon2Params(memory: 19456, iterations: 2, parallelism: 1, hashLength: 32),
  'm=46MiB t=1 p=1 (RFC9106)':
      Argon2Params(memory: 46080, iterations: 1, parallelism: 1, hashLength: 32),
};

Future<void> main() async {
  final salt = List<int>.generate(16, (i) => i);
  const runs = 3;
  for (final entry in _candidates.entries) {
    await Kdf(entry.value).deriveKey(password: 'warmup', salt: salt);
    final sw = Stopwatch()..start();
    for (var i = 0; i < runs; i++) {
      await Kdf(entry.value)
          .deriveKey(password: 'correct horse battery staple', salt: salt);
    }
    sw.stop();
    final avg = (sw.elapsedMilliseconds / runs).toStringAsFixed(0);
    // ignore: avoid_print
    print('${entry.key}: $avg ms/derivation');
  }
}
