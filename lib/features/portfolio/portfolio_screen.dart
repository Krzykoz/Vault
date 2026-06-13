import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model/money.dart';
import '../asset_editor/asset_editor_screen.dart';
import '../settings/settings_screen.dart';
import '../unlock/vault_controller.dart';
import 'portfolio_view.dart';

String _formatMoney(Money? money) =>
    money == null ? '—' : '${money.amount} ${money.currency.code}';

String _formatPercent(Decimal percent) {
  final value = percent.toDouble();
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(2)}%';
}

String _rowSubtitle(AssetRow row) {
  final buffer =
      StringBuffer('${row.quantity} · ${row.asset.symbol ?? assetTypeLabel(row.asset.type)}');
  if (row.priceAsOf != null) {
    buffer.write(' · as of ${row.priceAsOf!.toIso8601String().substring(0, 10)}');
    if (row.stale) buffer.write(' (stale)');
  }
  return buffer.toString();
}

Color _gainColor(BuildContext context, Money? gain) {
  if (gain == null) return Theme.of(context).colorScheme.onSurface;
  return gain.isNegative ? Colors.red.shade700 : Colors.green.shade700;
}

/// The open-vault home: total value, gain/loss, a refresh action, and holdings.
class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultControllerProvider);
    final payload = state.payload;
    final now = ref.watch(clockProvider).now();
    final notifier = ref.read(vaultControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio'),
        actions: [
          if (state.refreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              key: const Key('refresh'),
              tooltip: 'Refresh prices',
              icon: const Icon(Icons.refresh),
              onPressed: notifier.refresh,
            ),
          IconButton(
            key: const Key('settings'),
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            key: const Key('lock'),
            tooltip: 'Lock',
            icon: const Icon(Icons.lock_outline),
            onPressed: notifier.lock,
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.note != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(12),
              child: Text(state.note!, key: const Key('note')),
            ),
          Expanded(
            child: payload == null || payload.assets.isEmpty
                ? const Center(child: Text('No assets yet. Add your first one.'))
                : _PortfolioBody(view: buildPortfolioView(payload, now: now)),
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
                  subtitle: Text(_rowSubtitle(row)),
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
