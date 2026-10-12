import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy/data/database.dart';
import 'package:sy/data/providers.dart';
import 'package:sy/logic/vault_provider.dart';
import 'package:sy/screens/tracker_list_screen.dart';

class _ConfiguredVault extends VaultNotifier {
  _ConfiguredVault({this.biometric});
  final Completer<bool>? biometric;

  @override
  VaultState build() => VaultState(isBiometricsEnabled: biometric != null);

  @override
  Future<bool> isVaultConfigured() async => true;

  @override
  Future<bool> unlockVaultWithBiometrics() => biometric!.future;
}

Future<void> _pumpConfigured(WidgetTester tester, {Completer<bool>? bio}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        vaultProvider.overrideWith(() => _ConfiguredVault(biometric: bio)),
        trackerListProvider.overrideWith((ref) => Stream.value(<Tracker>[])),
        refreshStreaksProvider(false).overrideWith((ref) async {}),
      ],
      child: const MaterialApp(home: TrackerListScreen()),
    ),
  );
}

Future<void> _openUnlockField(WidgetTester tester) async {
  final gesture = await tester.startGesture(const Offset(200, 200));
  for (var i = 0; i < 10; i++) {
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

double _headerTop(WidgetTester tester) => tester
    .widget<AnimatedPositioned>(
      find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(AnimatedPositioned),
      ),
    )
    .top!;

void main() {
  group('unlock field and app lifecycle', () {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
    ]) {
      testWidgets('closes and clears when the app goes $state', (tester) async {
        await _pumpConfigured(tester);
        await tester.pumpAndSettle();
        await _openUnlockField(tester);

        await tester.enterText(find.byType(TextField), 'secret');
        expect(_headerTop(tester), 16);

        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pumpAndSettle();

        expect(_headerTop(tester), lessThan(0));
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
      });
    }

    testWidgets('stays open while the biometric prompt is showing', (
      tester,
    ) async {
      final bio = Completer<bool>();
      await _pumpConfigured(tester, bio: bio);
      await tester.pumpAndSettle();
      await _openUnlockField(tester);

      await tester.tap(find.byIcon(Icons.fingerprint));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(_headerTop(tester), 16);

      bio.complete(false);
      await tester.pumpAndSettle();
    });
  });
}
