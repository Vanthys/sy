import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/database.dart'; // For PrivacyLevel Enum
import '../data/vault_access.dart';
import '../services/biometric_auth_service.dart';
import '../services/screen_protection_service.dart';
import '../services/vault_storage_service.dart';
import '../utils/encryption_utils.dart'; // For hashing and derivation

part 'vault_provider.g.dart';

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
    Object? activeKey = _noActiveKeyChange,
    bool? isBiometricsEnabled,
    bool? isScreenProtectionEnabled,
  }) {
    return VaultState(
      unlockedLevel: unlockedLevel ?? this.unlockedLevel,
      activeKey: identical(activeKey, _noActiveKeyChange)
          ? this.activeKey
          : activeKey as enc.Key?,
      isBiometricsEnabled: isBiometricsEnabled ?? this.isBiometricsEnabled,
      isScreenProtectionEnabled:
          isScreenProtectionEnabled ?? this.isScreenProtectionEnabled,
    );
  }
}

const Object _noActiveKeyChange = Object();

@Riverpod(keepAlive: true)
class VaultNotifier extends _$VaultNotifier {
  @override
  VaultState build() {
    final flags = ref.watch(vaultStorageServiceProvider).loadFlags();
    return VaultState(
      isBiometricsEnabled: flags.biometricsEnabled,
      isScreenProtectionEnabled: flags.screenProtectionEnabled,
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
      final didAuthenticate = await ref
          .read(biometricAuthServiceProvider)
          .authenticateForVault();

      if (didAuthenticate) {
        // Retrieve the stored raw encryption key required to decrypt data (since we don't have the PIN)
        final rawKeyBase64 = await ref
            .read(vaultStorageServiceProvider)
            .readGeneralEncryptionKey();
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
  Future<void> lockVault() async {
    state = state.copyWith(
      unlockedLevel: PrivacyLevel.standard,
      activeKey: null,
    );
    try {
      await ref.read(screenProtectionServiceProvider).resetLockedState();
    } catch (_) {}
  }

  Future<void> _applyScreenProtectionIfNeeded() async {
    try {
      if (state.isVaultUnlocked && state.isScreenProtectionEnabled) {
        await ref.read(screenProtectionServiceProvider).enable();
      } else {
        await ref.read(screenProtectionServiceProvider).disable();
      }
    } catch (_) {}
  }

  Future<void> toggleBiometrics(bool enable) async {
    await ref.read(vaultStorageServiceProvider).setBiometricsEnabled(enable);
    state = state.copyWith(isBiometricsEnabled: enable);
  }

  Future<void> toggleScreenProtection(bool enable) async {
    await ref
        .read(vaultStorageServiceProvider)
        .setScreenProtectionEnabled(enable);
    state = state.copyWith(isScreenProtectionEnabled: enable);
    await _applyScreenProtectionIfNeeded();
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

    await ref.read(vaultStorageServiceProvider).writeGeneralPin(
      hashBase64: hashBase64,
      saltBase64: saltBase64,
      encryptionKeyBase64: aesKey.base64,
    );
  }

  Future<void> setSecretPin(String newPin) async {
    final saltBytes = EncryptionUtils.generateSalt();
    final saltBase64 = enc.IV(Uint8List.fromList(saltBytes)).base64;
    final hashBase64 = await EncryptionUtils.hashPinPbkdf2(newPin, saltBytes);

    await ref.read(vaultStorageServiceProvider).writeSecretPin(
      hashBase64: hashBase64,
      saltBase64: saltBase64,
    );
    // Note: We DO NOT store the raw AES key for the secret vault to maintain extreme privacy.
  }

  Future<bool> isVaultConfigured() async {
    return ref.read(vaultStorageServiceProvider).hasGeneralPin();
  }

  Future<bool> isSecretVaultConfigured() async {
    return ref.read(vaultStorageServiceProvider).hasSecretPin();
  }

  Future<bool> verifyGeneralPin(String pin) async {
    final hash = await ref.read(vaultStorageServiceProvider).readGeneralHash();
    final salt = await ref.read(vaultStorageServiceProvider).readGeneralSalt();
    if (hash == null || salt == null) return false;

    return await EncryptionUtils.verifyPinPbkdf2(pin, hash, salt);
  }

  Future<bool> verifySecretPin(String pin) async {
    final hash = await ref.read(vaultStorageServiceProvider).readSecretHash();
    final salt = await ref.read(vaultStorageServiceProvider).readSecretSalt();
    if (hash == null || salt == null) return false;

    return await EncryptionUtils.verifyPinPbkdf2(pin, hash, salt);
  }
}

@Riverpod(keepAlive: true)
VaultAccess vaultAccess(Ref ref) {
  final vaultState = ref.watch(vaultProvider);
  return VaultAccess(
    unlockedLevel: vaultState.unlockedLevel,
    activeKey: vaultState.activeKey,
  );
}
