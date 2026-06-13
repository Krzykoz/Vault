import 'dart:io';

/// Money-safety guard (authoritative implementation, shared by
/// `tool/guard_no_double.sh` and `test/security/core_money_safety_test.dart`):
///   1. lib/core must never use `double` — money math goes through `decimal`.
///   2. Production code (lib/) must never log via print/debugPrint, which could
///      spill secrets into logs.
///
/// The scan strips comments and string literals in source order (a single
/// stateful pass), so a `//` or quote inside a string can't hide a real
/// violation later on the same line. Interpolation expressions (`${...}`) are
/// kept as code, so a violation inside them is still caught.
void main() {
  final offenders = <String>[
    for (final f in scanForDouble()) "double  -> $f",
    for (final f in scanForLogging()) "print()  -> $f",
  ];
  if (offenders.isNotEmpty) {
    stderr.writeln('money-safety guard FAILED:');
    offenders.forEach(stderr.writeln);
    exit(1);
  }
  stdout.writeln('money-safety guard passed');
}

/// Files under lib/core that use the `double` type.
List<String> scanForDouble() =>
    _scan(Directory('lib/core'), RegExp(r'\bdouble\b'));

/// Files under lib/ that call print/debugPrint.
List<String> scanForLogging() =>
    _scan(Directory('lib'), RegExp(r'\b(?:print|debugPrint)\s*\('));

List<String> _scan(Directory dir, RegExp pattern) {
  final offenders = <String>[];
  if (!dir.existsSync()) return offenders;
  final files = dir.listSync(recursive: true).whereType<File>().where(
        (f) => f.path.endsWith('.dart'),
      );
  for (final file in files) {
    if (pattern.hasMatch(stripCommentsAndStrings(file.readAsStringSync()))) {
      offenders.add(file.path);
    }
  }
  offenders.sort();
  return offenders;
}

/// Removes comments and string-literal content from Dart [src], leaving the
/// surrounding code intact so identifiers and keywords stay matchable.
String stripCommentsAndStrings(String src) {
  final out = StringBuffer();
  final n = src.length;
  var i = 0;
  while (i < n) {
    final c = src[i];
    final next = i + 1 < n ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      while (i < n && src[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i < n && !(src[i] == '*' && i + 1 < n && src[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    if (c == "'" || c == '"') {
      i = _skipString(src, i, out);
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

/// Consumes a string literal beginning at [start]. Plain content is dropped;
/// interpolation expressions (`${...}`) are written to [out] as code so a
/// violation inside them is still scanned. Returns the index just past the
/// closing quote.
int _skipString(String src, int start, StringBuffer out) {
  final quote = src[start];
  final n = src.length;
  var i = start + 1;
  while (i < n) {
    final c = src[i];
    if (c == r'\') {
      i += 2;
      continue;
    }
    if (c == quote) return i + 1;
    if (c == r'$' && i + 1 < n && src[i + 1] == '{') {
      i += 2;
      var depth = 1;
      while (i < n && depth > 0) {
        final d = src[i];
        if (d == '{') {
          depth++;
        } else if (d == '}') {
          depth--;
        }
        if (depth > 0) out.write(d);
        i++;
      }
      continue;
    }
    i++;
  }
  return i;
}
