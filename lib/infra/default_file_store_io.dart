import 'package:path_provider/path_provider.dart';

import '../core/ports/file_store.dart';
import 'io_file_store.dart';

/// Native default: store the vault under the app support directory.
Future<FileStore> createDefaultFileStore() async {
  final dir = await getApplicationSupportDirectory();
  return IoFileStore('${dir.path}/vault.vlt');
}
