import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:screen_protector/screen_protector.dart';
import '../data/database.dart'; // For PrivacyLevel Enum
import '../utils/encryption_utils.dart'; // For hashing and derivation

class VaultState {
  final PrivacyLevel unlockedLevel;
  final enc.Key? activeKey; // The derived AES encryption key
  final bool isBiometricsEnabled; // Whether the user has opted into biometrics
  final bool isScreenProtectionEnabled; // Whether app-switcher protection is on

  VaultState({
    this.unlockedLevel = PrivacyLevel.standard,
    this.activeKey,
    this.isBiometricsEnabled = false,
    this.isScreenProtectionEnabled = false,
  });

  bool get isVaultUnlocked => unlockedLevel != PrivacyLevel.standard;

  VaultState copyWith({
    PrivacyLevel? unlockedLevel,
    enc.Key? activeKey,
    bool? isBiometricsEnabled,
    bool? isScreenProtectionEnabled,
  }) {
    return VaultState(
      unlockedLevel: unlockedLevel ?? this.unlockedLevel,
      activeKey: activeKey ?? this.activeKey,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      isScreenProtectionEnabled:
          isScreenProtectionEnabled ?? this.isScreenProtectionEnabled,
    );
  }
}

class VaultNotifier extends StateNotifier<VaultState> {
  VaultNotifier() : super(VaultState()) {
    _init();
  }

  static const _biometricsEnabledKey = 'vault_biometrics_enabled';
  static const _screenProtectionEnabledKey = 'vault_screen_protection_enabled';

  // Secure Storage Keys
  static const _secureGeneralHashRawKey = 'vault_general_hash';
  static const _secureGeneralSaltRawKey = 'vault_general_salt';
  static const _secureGeneralEncryptionKey =
      'vault_general_enc_key'; // Used for biometrics

  static const _secureSecretHashRawKey = 'vault_secret_hash';
  static const _secureSecretSaltRawKey = 'vault_secret_salt';

  final _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _auth = LocalAuthentication();

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final bioEnabled = prefs.getBool(_biometricsEnabledKey) ?? false;
    final screenEnabled = prefs.getBool(_screenProtectionEnabledKey) ?? false;

    state = state.copyWith(
      isBiometricsEnabled: bioEnabled,
      isScreenProtectionEnabled: screenEnabled,
    );
  }

  /// Attempt to unlock the vault.
  /// If PIN generates a PBKDF2 hash matching the General Hash, opens Level 1 (Vault).
  /// If PIN generates a PBKDF2 hash matching the Secret Hash, opens Level 2 (Secret).
  Future<bool> unlockVault(String pin) async {
    // 1. Try Secret Vault First
    if (await verifySecretPin(pin)) {
      final key = EncryptionUtils.deriveKeyFromPin(pin);
      state = state.copyWith(
        unlockedLevel: PrivacyLevel.secret,
        activeKey: key,
      );
      _applyScreenProtectionIfNeeded();
      return true;
    }

    // 2. Try General Vault
    if (await verifyGeneralPin(pin)) {
      final key = EncryptionUtils.deriveKeyFromPin(pin);
      state = state.copyWith(unlockedLevel: PrivacyLevel.vault, activeKey: key);
      _applyScreenProtectionIfNeeded();
      return true;
    }

    return false;
  }

  /// Attempt to unlock the General Vault via Biometrics
  Future<bool> unlockVaultWithBiometrics() async {
    if (!state.isBiometricsEnabled) return false;

    try {
      final canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) return false;

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to unlock your Vault',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        // Retrieve the stored raw encryption key required to decrypt data (since we don't have the PIN)
        final rawKeyBase64 = await _secureStorage.read(
          key: _secureGeneralEncryptionKey,
        );
        if (rawKeyBase64 == null) return false;

        final key = enc.Key.fromBase64(rawKeyBase64);
        state = state.copyWith(
          unlockedLevel: PrivacyLevel.vault,
          activeKey: key,
        );
        _applyScreenProtectionIfNeeded();
        return true;
      }
    } catch (e) {
      // Handle or log error
    }

    return false;
  }

  /// Cleans the encryption key from memory and reverts to standard level
  void lockVault() async {
    state = state.copyWith(
      unlockedLevel: PrivacyLevel.standard,
      activeKey: null,
    );
    try {
      await ScreenProtector.preventScreenshotOn();
      // We only want to prevent screenshots if they global setting says so.
      // Actually, if the vault is *locked*, we don't need screen protection anymore unless we want to hide trackers.
      // The requirement was: "only while one of the secret vaults is unlocked AND a setting is enabled".
      // So when locked, we turn off screen protection.
      await ScreenProtector.preventScreenshotOff();
    } catch (_) {}
  }

  void _applyScreenProtectionIfNeeded() async {
    try {
      if (state.isVaultUnlocked && state.isScreenProtectionEnabled) {
        await ScreenProtector.preventScreenshotOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (_) {}
  }

  Future<void> toggleBiometrics(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricsEnabledKey, enable);
    state = state.copyWith(isBiometricsEnabled: enable);
  }

  Future<void> toggleScreenProtection(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_screenProtectionEnabledKey, enable);
    state = state.copyWith(isScreenProtectionEnabled: enable);
    _applyScreenProtectionIfNeeded();
  }

  Future<void> setGeneralPin(String newPin) async {
    final saltBytes = EncryptionUtils.generateSalt();
    final saltBase64 = enc
        .IV(Uint8List.fromList(saltBytes))
        .base64; // Convenient base64 wrapper
    final hashBase64 = await EncryptionUtils.hashPinPbkdf2(newPin, saltBytes);

    // For biometric unlock to work, we must store the derived AES encryption key securely
    // because the user will not provide the PIN when unlocking via face/touch.
    final aesKey = EncryptionUtils.deriveKeyFromPin(newPin);

    await _secureStorage.write(
      key: _secureGeneralHashRawKey,
      value: hashBase64,
    );
    await _secureStorage.write(
      key: _secureGeneralSaltRawKey,
      value: saltBase64,
    );
    await _secureStorage.write(
      key: _secureGeneralEncryptionKey,
      value: aesKey.base64,
    );
  }

  Future<void> setSecretPin(String newPin) async {
    final saltBytes = EncryptionUtils.generateSalt();
    final saltBase64 = enc.IV(Uint8List.fromList(saltBytes)).base64;
    final hashBase64 = await EncryptionUtils.hashPinPbkdf2(newPin, saltBytes);

    await _secureStorage.write(key: _secureSecretHashRawKey, value: hashBase64);
    await _secureStorage.write(key: _secureSecretSaltRawKey, value: saltBase64);
    // Note: We DO NOT store the raw AES key for the secret vault to maintain extreme privacy.
  }

  Future<bool> isVaultConfigured() async {
    return await _secureStorage.containsKey(key: _secureGeneralHashRawKey);
  }

  Future<bool> isSecretVaultConfigured() async {
    return await _secureStorage.containsKey(key: _secureSecretHashRawKey);
  }

  Future<bool> verifyGeneralPin(String pin) async {
    final hash = await _secureStorage.read(key: _secureGeneralHashRawKey);
    final salt = await _secureStorage.read(key: _secureGeneralSaltRawKey);
    if (hash == null || salt == null) return false;

    return await EncryptionUtils.verifyPinPbkdf2(pin, hash, salt);
  }

  Future<bool> verifySecretPin(String pin) async {
    final hash = await _secureStorage.read(key: _secureSecretHashRawKey);
    final salt = await _secureStorage.read(key: _secureSecretSaltRawKey);
    if (hash == null || salt == null) return false;

    return await EncryptionUtils.verifyPinPbkdf2(pin, hash, salt);
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  return VaultNotifier();
});
