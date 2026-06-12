import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/model/asset.dart';
import '../../core/model/currency.dart';
import '../../core/model/money.dart';
import '../unlock/vault_controller.dart';
import 'lot_editor_screen.dart';

String assetTypeLabel(AssetType type) => switch (type) {
      AssetType.stock => 'Stock',
      AssetType.etf => 'ETF',
      AssetType.crypto => 'Crypto',
      AssetType.commodity => 'Commodity',
      AssetType.cash => 'Cash',
      AssetType.manual => 'Manual',
    };

Decimal? _tryDecimal(String value) {
  try {
    return Decimal.parse(value.trim());
  } catch (_) {
    return null;
  }
}

/// Create or edit an [Asset], and manage its lots when editing.
class AssetEditorScreen extends ConsumerStatefulWidget {
  final Asset? existing;

  const AssetEditorScreen({super.key, this.existing});

  @override
  ConsumerState<AssetEditorScreen> createState() => _AssetEditorScreenState();
}

class _AssetEditorScreenState extends ConsumerState<AssetEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _id;
  late AssetType _type;
  late final TextEditingController _name;
  late final TextEditingController _symbol;
  late final TextEditingController _currency;
  late final TextEditingController _manualPrice;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  bool get _priced =>
      _type == AssetType.stock ||
      _type == AssetType.etf ||
      _type == AssetType.crypto ||
      _type == AssetType.commodity;

  @override
  void initState() {
    super.initState();
    final asset = widget.existing;
    _id = asset?.id ?? const Uuid().v4();
    _type = asset?.type ?? AssetType.stock;
    _name = TextEditingController(text: asset?.name ?? '');
    _symbol = TextEditingController(text: asset?.symbol ?? '');
    _currency = TextEditingController(text: asset?.nativeCurrency.code ?? 'USD');
    _manualPrice =
        TextEditingController(text: asset?.manualPrice?.amount.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _symbol.dispose();
    _currency.dispose();
    _manualPrice.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final currency = Currency(_currency.text);
    final manualText = _manualPrice.text.trim();
    final asset = Asset(
      id: _id,
      type: _type,
      name: _name.text.trim(),
      nativeCurrency: currency,
      symbol: _priced ? _symbol.text.trim() : null,
      manualPrice: manualText.isEmpty
          ? null
          : Money(Decimal.parse(manualText), currency),
    );
    await ref.read(vaultControllerProvider.notifier).upsertAsset(asset);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _deleteAsset() async {
    setState(() => _saving = true);
    await ref.read(vaultControllerProvider.notifier).deleteAsset(_id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lots = ref
            .watch(vaultControllerProvider)
            .payload
            ?.lots
            .where((l) => l.assetId == _id)
            .toList() ??
        const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit asset' : 'Add asset'),
        actions: [
          if (_isEditing)
            IconButton(
              key: const Key('delete-asset'),
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _deleteAsset,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<AssetType>(
                  key: const Key('type'),
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final type in AssetType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(assetTypeLabel(type)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _type = value ?? _type),
                ),
                TextFormField(
                  key: const Key('name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                if (_priced)
                  TextFormField(
                    key: const Key('symbol'),
                    controller: _symbol,
                    decoration: const InputDecoration(labelText: 'Symbol'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Required for priced assets'
                        : null,
                  ),
                TextFormField(
                  key: const Key('currency'),
                  controller: _currency,
                  decoration:
                      const InputDecoration(labelText: 'Native currency'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                if (!_priced)
                  TextFormField(
                    key: const Key('manualPrice'),
                    controller: _manualPrice,
                    decoration: const InputDecoration(
                      labelText: 'Manual price (optional)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      return _tryDecimal(v) == null ? 'Enter a number' : null;
                    },
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('save-asset'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
          if (_isEditing) ...[
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lots', style: Theme.of(context).textTheme.titleMedium),
                TextButton.icon(
                  key: const Key('add-lot'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LotEditorScreen(
                        assetId: _id,
                        defaultCurrency: widget.existing!.nativeCurrency,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Add lot'),
                ),
              ],
            ),
            if (lots.isEmpty) const Text('No lots yet.'),
            for (final lot in lots)
              ListTile(
                key: Key('lot-${lot.id}'),
                title: Text('${lot.quantity} @ ${lot.unitCost}'),
                subtitle:
                    Text(lot.date.toIso8601String().substring(0, 10)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async => ref
                      .read(vaultControllerProvider.notifier)
                      .deleteLot(lot.id),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LotEditorScreen(
                      assetId: _id,
                      existing: lot,
                      defaultCurrency: lot.unitCost.currency,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
