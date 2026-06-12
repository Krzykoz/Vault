import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../asset_editor/asset_editor_screen.dart';
import '../unlock/vault_controller.dart';

/// The open-vault home: a list of assets with add/edit/delete. A later task adds
/// live values and gain/loss on top of this.
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(vaultControllerProvider).payload?.assets ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          IconButton(
            key: const Key('lock'),
            tooltip: 'Lock',
            icon: const Icon(Icons.lock_outline),
            onPressed: () => ref.read(vaultControllerProvider.notifier).lock(),
          ),
        ],
      ),
      body: assets.isEmpty
          ? const Center(child: Text('No assets yet. Add your first one.'))
          : ListView(
              children: [
                for (final asset in assets)
                  ListTile(
                    key: Key('asset-${asset.id}'),
                    title: Text(asset.name),
                    subtitle: Text(asset.symbol ?? assetTypeLabel(asset.type)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssetEditorScreen(existing: asset),
                      ),
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        key: const Key('add-asset'),
        tooltip: 'Add asset',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AssetEditorScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
