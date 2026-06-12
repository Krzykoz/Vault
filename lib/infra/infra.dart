/// Barrel for cross-platform infra adapters. `io_file_store.dart` is
/// deliberately excluded because it imports `dart:io` and is native-only;
/// import it directly where needed.
library;

export 'biometric_gate_impl.dart';
export 'http_client_impl.dart';
export 'secure_store_impl.dart';
export 'system_clock.dart';
