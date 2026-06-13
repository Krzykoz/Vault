import 'dart:typed_data';

import '../core/ports/file_store.dart';

/// Opens a file picker and returns the chosen bytes, or null if cancelled.
typedef BytePicker = Future<Uint8List?> Function();

/// Triggers a browser download of [bytes] as [filename].
typedef ByteDownloader = void Function(Uint8List bytes, String filename);

/// The web [FileStore]: there is no persistent path, so it holds the loaded file
/// in memory. [write] keeps the latest bytes and triggers a download of the
/// re-encrypted vault; [pickInto] loads a file the user chooses. The browser
/// specifics are injected, so this logic is testable off-browser.
class WebFileStore implements FileStore, FilePicker {
  Uint8List? _bytes;
  final BytePicker _pick;
  final ByteDownloader _download;
  final String filename;

  WebFileStore({
    required BytePicker pick,
    required ByteDownloader download,
    this.filename = 'vault.vlt',
  })  : _pick = pick,
        _download = download;

  @override
  Future<Uint8List?> read() async => _bytes;

  @override
  Future<void> write(Uint8List bytes) async {
    _bytes = bytes;
    _download(bytes, filename);
  }

  @override
  Future<bool> pickInto() async {
    final bytes = await _pick();
    if (bytes == null) return false;
    _bytes = bytes;
    return true;
  }
}
