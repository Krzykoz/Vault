import 'dart:typed_data';

/// Reads and writes the raw bytes of a single vault file. Implementations decide
/// where the bytes live — a file path on native platforms, or a download/upload
/// in the browser.
abstract interface class FileStore {
  /// Returns the stored bytes, or null if nothing is stored yet or the user
  /// cancelled an open dialog.
  Future<Uint8List?> read();

  /// Persists [bytes] — writes the file, or triggers a download on web.
  Future<void> write(Uint8List bytes);
}
