import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'create_vault_screen.dart';
import 'open_home.dart';
import 'unlock_screen.dart';
import 'vault_controller.dart';

/// Routes to the right screen based on whether a vault exists and is open.
class VaultGate extends ConsumerWidget {
  const VaultGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(vaultControllerProvider).phase;
    switch (phase) {
      case VaultPhase.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case VaultPhase.absent:
        return const CreateVaultScreen();
      case VaultPhase.locked:
        return const UnlockScreen();
      case VaultPhase.open:
        return const OpenHome();
    }
  }
}
