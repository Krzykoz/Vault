import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/unlock/vault_controller.dart';
import 'features/unlock/vault_gate.dart';
import 'infra/default_file_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fileStore = await createDefaultFileStore();
  runApp(
    ProviderScope(
      overrides: [vaultFileStoreProvider.overrideWithValue(fileStore)],
      child: const VaultApp(),
    ),
  );
}

class VaultApp extends StatelessWidget {
  const VaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const VaultGate(),
    );
  }
}
