import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: VaultApp()));
}

/// Root of the Vault app. Real screens arrive in later tasks; this placeholder
/// keeps the project building and booting on every target platform.
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
      home: const SetupHome(),
    );
  }
}

class SetupHome extends StatelessWidget {
  const SetupHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
      body: const Center(child: Text('Vault setup complete')),
    );
  }
}
