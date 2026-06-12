import '../core/ports/file_store.dart';
// Picks the native (dart:io) implementation when available, otherwise the web
// stub. `dart.library.io` is present on mobile/desktop but not on web.
import 'default_file_store_web.dart'
    if (dart.library.io) 'default_file_store_io.dart' as impl;

/// Builds the platform's default [FileStore] for the vault file.
Future<FileStore> createDefaultFileStore() => impl.createDefaultFileStore();
