import 'package:flutter_test/flutter_test.dart';

import '../../tool/guard_no_double.dart' as guard;

/// Static guards protecting the money/privacy invariants across the whole
/// domain core. Uses the same scanner as `tool/guard_no_double.sh`, so the two
/// can never disagree.
void main() {
  test('lib/core never uses `double` (money stays exact via Decimal)', () {
    final offenders = guard.scanForDouble();
    expect(
      offenders,
      isEmpty,
      reason: 'Use Decimal, not double, for money: $offenders',
    );
  });

  test('production code never logs via print/debugPrint', () {
    final offenders = guard.scanForLogging();
    expect(
      offenders,
      isEmpty,
      reason: 'Do not log from production code (it can leak secrets): '
          '$offenders',
    );
  });

  group('the scanner itself', () {
    test('ignores matches inside comments and strings', () {
      const src = '''
// double in a line comment
/* double in a block comment */
final url = 'http://double.example';
final s = "say double here";
''';
      expect(
        RegExp(r'\bdouble\b').hasMatch(guard.stripCommentsAndStrings(src)),
        isFalse,
      );
    });

    test('still catches a violation hidden after a string with //', () {
      // The earlier sed/regex approach erased everything after `//` inside the
      // string, masking the real `double` that follows.
      const src = "final url = 'http://example'; double amount = readIt();";
      expect(
        RegExp(r'\bdouble\b').hasMatch(guard.stripCommentsAndStrings(src)),
        isTrue,
      );
    });

    test('catches a violation inside string interpolation', () {
      const src = r"final s = '${double.parse(x)}';";
      expect(
        RegExp(r'\bdouble\b').hasMatch(guard.stripCommentsAndStrings(src)),
        isTrue,
      );
    });
  });
}
