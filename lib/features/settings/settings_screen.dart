import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/model/currency.dart';
import '../unlock/vault_controller.dart';

/// Vault settings — currently just the base/display currency.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _common = [
    'USD',
    'EUR',
    'GBP',
    'PLN',
    'JPY',
    'CHF',
    'CAD',
    'AUD',
    'SEK',
    'NOK',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vaultControllerProvider);
    final base = state.payload?.settings.baseCurrency.code ?? 'USD';
    final codes = ({..._common, base}.toList()..sort());

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Base currency'),
            subtitle: const Text(
              'Totals and gain/loss are shown in this currency. '
              'Changing it fetches fresh rates.',
            ),
            trailing: DropdownButton<String>(
              key: const Key('base-currency'),
              value: base,
              onChanged: state.refreshing
                  ? null
                  : (code) {
                      if (code != null && code != base) {
                        ref
                            .read(vaultControllerProvider.notifier)
                            .setBaseCurrency(Currency(code));
                      }
                    },
              items: [
                for (final code in codes)
                  DropdownMenuItem(value: code, child: Text(code)),
              ],
            ),
          ),
          if (state.refreshing) const LinearProgressIndicator(),
          if (state.note != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(state.note!, key: const Key('settings-note')),
            ),
        ],
      ),
    );
  }
}
