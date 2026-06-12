import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vault_controller.dart';

/// Placeholder shown once the vault is open. The real portfolio dashboard
/// replaces this in a later task.
class OpenHome extends ConsumerWidget {
  const OpenHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultControllerProvider);
    final assetCount = state.payload?.assets.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          IconButton(
            key: const Key('lock'),
            tooltip: 'Lock',
            onPressed: () => ref.read(vaultControllerProvider.notifier).lock(),
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: Center(child: Text('Vault unlocked — $assetCount assets')),
    );
  }
}
