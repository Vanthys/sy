import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sy3/data/database.dart';
import 'package:sy3/logic/vault_provider.dart';
import 'package:sy3/utils/encryption_utils.dart';

const MethodChannel _localAuthChannel = MethodChannel(
  'plugins.flutter.io/local_auth',
);
const MethodChannel _screenProtectorChannel = MethodChannel('screen_protector');

class _LocalAuthState {
  List<String> availableBiometrics = const [];
  bool isDeviceSupported = false;
  bool authenticateResult = false;
  int authenticateCalls = 0;
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (var i = 0; i < 200; i++) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  fail('Condition was not met before timeout.');
}

Future<VaultNotifier> _createNotifier({
  Map<String, Object> prefs = const {},
  Map<String, String> secureStorage = const {},
}) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.of(prefs));
  FlutterSecureStorage.setMockInitialValues(
    Map<String, String>.of(secureStorage),
  );

  final notifier = VaultNotifier();
  addTearDown(notifier.dispose);
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _LocalAuthState localAuthState;
  late List<String> screenProtectorCalls;

  setUp(() async {
    localAuthState = _LocalAuthState();
    screenProtectorCalls = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localAuthChannel, (call) async {
          switch (call.method) {
            case 'getAvailableBiometrics':
              return localAuthState.availableBiometrics;
            case 'isDeviceSupported':
              return localAuthState.isDeviceSupported;
            case 'authenticate':
              localAuthState.authenticateCalls++;
              return localAuthState.authenticateResult;
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_screenProtectorChannel, (call) async {
          screenProtectorCalls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localAuthChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_screenProtectorChannel, null);
  });

  group('VaultNotifier', () {
    test('loads biometrics and screen protection preferences on init', () async {
      final notifier = await _createNotifier(
        prefs: const {
          'vault_biometrics_enabled': true,
          'vault_screen_protection_enabled': true,
        },
      );

      await _waitUntil(
        () =>
            notifier.state.isBiometricsEnabled &&
            notifier.state.isScreenProtectionEnabled,
      );

      expect(notifier.state.unlockedLevel, PrivacyLevel.standard);
      expect(notifier.state.activeKey, isNull);
    });

    test('setGeneralPin stores configuration and verifies the correct pin', () async {
      final notifier = await _createNotifier();

      await notifier.setGeneralPin('2468');

      expect(await notifier.isVaultConfigured(), isTrue);
      expect(await notifier.verifyGeneralPin('2468'), isTrue);
      expect(await notifier.verifyGeneralPin('1357'), isFalse);

      final stored = await const FlutterSecureStorage().readAll();
      expect(stored['vault_general_hash'], isNotNull);
      expect(stored['vault_general_salt'], isNotNull);
      expect(stored['vault_general_enc_key'], isNotNull);
    });

    test('setSecretPin stores configuration and unlockVault prefers secret level', () async {
      final notifier = await _createNotifier();

      await notifier.setGeneralPin('1111');
      await notifier.setSecretPin('2222');

      expect(await notifier.isSecretVaultConfigured(), isTrue);
      expect(await notifier.verifySecretPin('2222'), isTrue);

      final unlocked = await notifier.unlockVault('2222');

      expect(unlocked, isTrue);
      expect(notifier.state.unlockedLevel, PrivacyLevel.secret);
      expect(
        notifier.state.activeKey!.base64,
        EncryptionUtils.deriveKeyFromPin('2222').base64,
      );
      expect(screenProtectorCalls.last, 'preventScreenshotOff');
    });

    test('unlockVault opens the general vault and wrong pins leave state locked', () async {
      final notifier = await _createNotifier();

      await notifier.setGeneralPin('1234');

      expect(await notifier.unlockVault('0000'), isFalse);
      expect(notifier.state.unlockedLevel, PrivacyLevel.standard);
      expect(notifier.state.activeKey, isNull);

      final unlocked = await notifier.unlockVault('1234');

      expect(unlocked, isTrue);
      expect(notifier.state.unlockedLevel, PrivacyLevel.vault);
      expect(
        notifier.state.activeKey!.base64,
        EncryptionUtils.deriveKeyFromPin('1234').base64,
      );
    });

    test('unlockVaultWithBiometrics unlocks vault when enabled and auth succeeds', () async {
      final biometricKey = EncryptionUtils.deriveKeyFromPin('biometric-pin');
      localAuthState.availableBiometrics = ['fingerprint'];
      localAuthState.authenticateResult = true;

      final notifier = await _createNotifier(
        prefs: const {
          'vault_biometrics_enabled': true,
          'vault_screen_protection_enabled': true,
        },
        secureStorage: {
          'vault_general_enc_key': biometricKey.base64,
        },
      );

      await _waitUntil(
        () =>
            notifier.state.isBiometricsEnabled &&
            notifier.state.isScreenProtectionEnabled,
      );

      final unlocked = await notifier.unlockVaultWithBiometrics();

      await _waitUntil(() => screenProtectorCalls.contains('preventScreenshotOn'));

      expect(unlocked, isTrue);
      expect(localAuthState.authenticateCalls, 1);
      expect(notifier.state.unlockedLevel, PrivacyLevel.vault);
      expect(notifier.state.activeKey!.base64, biometricKey.base64);
      expect(screenProtectorCalls.last, 'preventScreenshotOn');
    });

    test('unlockVaultWithBiometrics returns false when biometrics are disabled', () async {
      localAuthState.availableBiometrics = ['fingerprint'];
      localAuthState.authenticateResult = true;
      final notifier = await _createNotifier();

      final unlocked = await notifier.unlockVaultWithBiometrics();

      expect(unlocked, isFalse);
      expect(localAuthState.authenticateCalls, 0);
      expect(notifier.state.unlockedLevel, PrivacyLevel.standard);
    });

    test('toggleScreenProtection persists the flag and lockVault clears access', () async {
      final notifier = await _createNotifier();

      await notifier.setGeneralPin('9876');
      await notifier.unlockVault('9876');
      screenProtectorCalls.clear();

      await notifier.toggleScreenProtection(true);
      await _waitUntil(() => screenProtectorCalls.contains('preventScreenshotOn'));

      expect(notifier.state.isScreenProtectionEnabled, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'vault_screen_protection_enabled',
        ),
        isTrue,
      );
      expect(screenProtectorCalls.last, 'preventScreenshotOn');

      notifier.lockVault();
      await _waitUntil(
        () =>
            screenProtectorCalls.contains('preventScreenshotOff') &&
            screenProtectorCalls.length >= 3,
      );

      expect(notifier.state.unlockedLevel, PrivacyLevel.standard);
      expect(notifier.state.activeKey, isNull);
      expect(
        screenProtectorCalls.sublist(screenProtectorCalls.length - 2),
        ['preventScreenshotOn', 'preventScreenshotOff'],
      );
    });
  });
}
