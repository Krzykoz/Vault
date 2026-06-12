import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vault/main.dart';

void main() {
  testWidgets('boots to the setup placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VaultApp()));
    expect(find.text('Vault setup complete'), findsOneWidget);
  });
}
