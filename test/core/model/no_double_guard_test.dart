import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard: monetary values must use `Decimal`, never `double`. This keeps money
/// math exact and is the lightweight precursor to the repo-wide check in a
/// later task. Comments and string literals are stripped first so the word
/// `double` can still appear in documentation.
void main() {
  test('no `double` type appears in lib/core/model', () {
    final dir = Directory('lib/core/model');
    final offenders = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final code = _codeOnly(entity.readAsStringSync());
        if (RegExp(r'\bdouble\b').hasMatch(code)) {
          offenders.add(entity.path);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use Decimal, not double, for money: $offenders',
    );
  });
}

/// Strips block comments, line comments, and string literals so the scan only
/// sees actual code.
String _codeOnly(String src) {
  return src
      .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
      .replaceAll(RegExp(r'//[^\n]*'), '')
      .replaceAll(RegExp(r"'(\\.|[^'\\])*'"), '')
      .replaceAll(RegExp(r'"(\\.|[^"\\])*"'), '');
}

