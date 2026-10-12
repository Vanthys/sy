import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy/data/database.dart';
import 'package:sy/logic/vault_provider.dart';
import 'package:sy/screens/settings/vault_pin_screen.dart';
import 'package:sy/utils/encryption_utils.dart';

class _FakeVault extends VaultNotifier {
  _FakeVault(this._initial);
  final VaultState _initial;

  @override
  VaultState build() => _initial;
}

Future<void> _pump(
  WidgetTester tester, {
  required VaultState vault,
  bool isSecret = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [vaultProvider.overrideWith(() => _FakeVault(vault))],
      child: MaterialApp(
        home: VaultPinScreen(isSecret: isSecret, isConfigured: true),
      ),
    ),
  );
}

void main() {
  const forgot = 'Forgot it? Use my unlocked vault';

  testWidgets(
    'offers skipping the current passphrase when general vault is open',
    (tester) async {
      await _pump(
        tester,
        vault: VaultState(
          unlockedLevel: PrivacyLevel.vault,
          activeKey: EncryptionUtils.deriveKeyFromPin('1234'),
        ),
      );

      expect(find.text('Current Passphrase'), findsOneWidget);
      await tester.tap(find.text(forgot));
      await tester.pump();

      expect(find.text('Current Passphrase'), findsNothing);
      expect(find.text('Enter current passphrase instead'), findsOneWidget);

      await tester.tap(find.text('Enter current passphrase instead'));
      await tester.pump();
      expect(find.text('Current Passphrase'), findsOneWidget);
    },
  );

  testWidgets('does not offer it when the vault is locked', (tester) async {
    await _pump(tester, vault: VaultState());
    expect(find.text(forgot), findsNothing);
  });

  testWidgets('does not offer it for the secret vault', (tester) async {
    await _pump(
      tester,
      vault: VaultState(
        unlockedLevel: PrivacyLevel.secret,
        activeKey: EncryptionUtils.deriveKeyFromPin('1234'),
      ),
      isSecret: true,
    );
    expect(find.text(forgot), findsNothing);
  });
}
