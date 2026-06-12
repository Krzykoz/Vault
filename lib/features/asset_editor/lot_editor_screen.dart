import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/model/currency.dart';
import '../../core/model/lot.dart';
import '../../core/model/money.dart';
import '../unlock/vault_controller.dart';

Decimal? _tryDecimal(String value) {
  try {
    return Decimal.parse(value.trim());
  } catch (_) {
    return null;
  }
}

/// Create or edit a [Lot] (a single purchase) belonging to an asset.
class LotEditorScreen extends ConsumerStatefulWidget {
  final String assetId;
  final Lot? existing;
  final Currency defaultCurrency;

  const LotEditorScreen({
    super.key,
    required this.assetId,
    required this.defaultCurrency,
    this.existing,
  });

  @override
  ConsumerState<LotEditorScreen> createState() => _LotEditorScreenState();
}

class _LotEditorScreenState extends ConsumerState<LotEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _quantity;
  late final TextEditingController _unitCost;
  late final TextEditingController _currency;
  late final TextEditingController _fee;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final lot = widget.existing;
    _id = lot?.id ?? const Uuid().v4();
    _quantity = TextEditingController(text: lot?.quantity.toString() ?? '');
    _unitCost = TextEditingController(text: lot?.unitCost.amount.toString() ?? '');
    _currency = TextEditingController(
      text: (lot?.unitCost.currency ?? widget.defaultCurrency).code,
    );
    _fee = TextEditingController(text: lot?.fee?.amount.toString() ?? '');
    _date = lot?.date ?? DateTime.now().toUtc();
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitCost.dispose();
    _currency.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.toLocal(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = DateTime.utc(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final currency = Currency(_currency.text);
    final feeText = _fee.text.trim();
    final lot = Lot(
      id: _id,
      assetId: widget.assetId,
      quantity: Decimal.parse(_quantity.text.trim()),
      unitCost: Money(Decimal.parse(_unitCost.text.trim()), currency),
      date: _date,
      fee: feeText.isEmpty ? null : Money(Decimal.parse(feeText), currency),
    );
    await ref.read(vaultControllerProvider.notifier).upsertLot(lot);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date.toIso8601String().substring(0, 10);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Add lot' : 'Edit lot'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                key: const Key('quantity'),
                controller: _quantity,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final value = v == null ? null : _tryDecimal(v);
                  if (value == null) return 'Enter a number';
                  if (value <= Decimal.zero) return 'Must be greater than zero';
                  return null;
                },
              ),
              TextFormField(
                key: const Key('unitCost'),
                controller: _unitCost,
                decoration: const InputDecoration(labelText: 'Unit cost'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    (v == null || _tryDecimal(v) == null) ? 'Enter a number' : null,
              ),
              TextFormField(
                key: const Key('lot-currency'),
                controller: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                key: const Key('fee'),
                controller: _fee,
                decoration:
                    const InputDecoration(labelText: 'Fee (optional)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  return _tryDecimal(v) == null ? 'Enter a number' : null;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: Text('Purchase date: $dateLabel')),
                  TextButton(
                    key: const Key('pick-date'),
                    onPressed: _pickDate,
                    child: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('save-lot'),
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
      ),
    );
  }
}
