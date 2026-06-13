import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:web/web.dart' as web;

import '../core/ports/file_store.dart';
import 'web_file_store.dart';

/// Web default: an in-memory store backed by a file picker (load) and a browser
/// download (save). No backend is involved.
Future<FileStore> createDefaultFileStore() async {
  return WebFileStore(pick: _pickBytes, download: _downloadBytes);
}

Future<Uint8List?> _pickBytes() async {
  const group = XTypeGroup(label: 'Vault', extensions: ['vlt']);
  final file = await openFile(acceptedTypeGroups: [group]);
  if (file == null) return null;
  return file.readAsBytes();
}

void _downloadBytes(Uint8List bytes, String filename) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
