import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'vault_controller.dart';

/// Returning-user screen: enter the master password to decrypt the vault.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _password = TextEditingController();
  bool _enableBiometric = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_password.text.isEmpty) return;
    ref.read(vaultControllerProvider.notifier).unlock(
          password: _password.text,
          enableBiometric: _enableBiometric,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock your vault')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const Key('password'),
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Master password'),
                  onSubmitted: (_) => _submit(),
                ),
                if (state.biometricAvailable && !state.biometricEnrolled) ...[
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    key: const Key('enable-biometric'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _enableBiometric,
                    onChanged: state.busy
                        ? null
                        : (value) =>
                            setState(() => _enableBiometric = value ?? false),
                    title: const Text('Unlock with biometrics next time'),
                  ),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('unlock'),
                  onPressed: state.busy ? null : _submit,
                  child: state.busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Unlock'),
                ),
                if (state.biometricEnrolled) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('unlock-biometric'),
                    onPressed: state.busy
                        ? null
                        : () => ref
                            .read(vaultControllerProvider.notifier)
                            .unlockWithBiometrics(),
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Unlock with biometrics'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
