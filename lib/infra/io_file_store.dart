import 'dart:io';
import 'dart:typed_data';

import '../core/ports/file_store.dart';

/// [FileStore] backed by a file on disk at a fixed [path]. Native only — the web
/// target uses a download/upload-based store (added in a later task), so this
/// file is imported directly rather than from a shared barrel.
class IoFileStore implements FileStore {
  final String path;

  const IoFileStore(this.path);

  @override
  Future<Uint8List?> read() async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
}
