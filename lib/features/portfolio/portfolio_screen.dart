import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model/money.dart';
import '../asset_editor/asset_editor_screen.dart';
import '../unlock/vault_controller.dart';
import 'portfolio_view.dart';

String _formatMoney(Money? money) =>
    money == null ? '—' : '${money.amount} ${money.currency.code}';

String _formatPercent(Decimal percent) {
  final value = percent.toDouble();
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

Color _gainColor(BuildContext context, Money? gain) {
  if (gain == null) return Theme.of(context).colorScheme.onSurface;
  return gain.isNegative ? Colors.red.shade700 : Colors.green.shade700;
}

/// The open-vault home: total value, gain/loss, and a list of holdings.
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payload = ref.watch(vaultControllerProvider).payload;
    final now = ref.watch(clockProvider).now();

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
      body: payload == null || payload.assets.isEmpty
          ? const Center(child: Text('No assets yet. Add your first one.'))
          : _PortfolioBody(view: buildPortfolioView(payload, now: now)),
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

class _PortfolioBody extends StatelessWidget {
  final PortfolioView view;

  const _PortfolioBody({required this.view});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TotalHeader(view: view),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              for (final row in view.rows)
                ListTile(
                  key: Key('asset-${row.asset.id}'),
                  title: Text(row.asset.name),
                  subtitle: Text(
                    '${row.quantity} · ${row.asset.symbol ?? assetTypeLabel(row.asset.type)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatMoney(row.value)),
                      if (row.gainPercent != null)
                        Text(
                          _formatPercent(row.gainPercent!),
                          style: TextStyle(
                            color: _gainColor(context, row.gain),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AssetEditorScreen(existing: row.asset),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalHeader extends StatelessWidget {
  final PortfolioView view;

  const _TotalHeader({required this.view});

  @override
  Widget build(BuildContext context) {
    final percent = view.totalGainPercent;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total value', style: Theme.of(context).textTheme.labelMedium),
          Text(
            _formatMoney(view.totalValue),
            key: const Key('total-value'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatMoney(view.totalGain)}'
            '${percent == null ? '' : ' (${_formatPercent(percent)})'}',
            key: const Key('total-gain'),
            style: TextStyle(color: _gainColor(context, view.totalGain)),
          ),
        ],
      ),
    );
  }
}
