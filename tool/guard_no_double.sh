#!/usr/bin/env bash
# Thin wrapper around the authoritative Dart scanner so the shell guard and the
# test in test/security can never diverge. Fails if lib/core uses `double` or if
# production code logs via print/debugPrint.
set -euo pipefail

cd "$(dirname "$0")/.."

exec dart run tool/guard_no_double.dart
