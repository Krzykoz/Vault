import '../core/ports/file_store.dart';

/// Web placeholder. The browser file-picker/download store is added in a later
/// task; until then, building it on web fails fast.
Future<FileStore> createDefaultFileStore() async {
  throw UnsupportedError(
    'Web vault storage is not wired up yet (see the web target task).',
  );
}
