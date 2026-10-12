import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy/data/database.dart';
import 'package:sy/data/providers.dart';
import 'package:sy/logic/vault_provider.dart';
import 'package:sy/screens/settings/vault_settings_screen.dart';
import 'package:sy/screens/tracker_list_screen.dart';

int _configuredChecks = 0;

class _UnconfiguredVault extends VaultNotifier {
  @override
  VaultState build() => VaultState();

  @override
  Future<bool> isVaultConfigured() async {
    _configuredChecks++;
    return false;
  }

  @override
  Future<bool> isSecretVaultConfigured() async => false;
}

Future<void> _pump(WidgetTester tester) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        vaultProvider.overrideWith(_UnconfiguredVault.new),
        trackerListProvider.overrideWith((ref) => Stream.value(<Tracker>[])),
        refreshStreaksProvider(false).overrideWith((ref) async {}),
      ],
      child: const MaterialApp(home: TrackerListScreen()),
    ),
  );
}

void main() {
  const message = 'Vault is not set up.';

  setUp(() => _configuredChecks = 0);

  testWidgets('pulling down shows the not-set-up message only once', (
    tester,
  ) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    // hold the pull past the threshold
    final gesture = await tester.startGesture(const Offset(200, 200));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(message), findsOneWidget);

    // keep holding while the first one times out: nothing may be queued
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(0, 2));
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text(message), findsNothing);
    expect(_configuredChecks, 1);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('the message has a Go to Settings action', (tester) async {
    await _pump(tester);
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(200, 200));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Go to Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(VaultSettingsScreen), findsOneWidget);
  });
}
