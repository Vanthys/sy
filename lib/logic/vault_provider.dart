import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/database.dart'; // For PrivacyLevel Enum

class VaultState {
  final PrivacyLevel unlockedLevel;
  final String? activeKey; // The verified PIN

  VaultState({this.unlockedLevel = PrivacyLevel.standard, this.activeKey});

  bool get isVaultUnlocked => unlockedLevel != PrivacyLevel.standard;
}

class VaultNotifier extends StateNotifier<VaultState> {
  VaultNotifier() : super(VaultState());

  static const _generalPinKey = 'vault_general_pin';
  static const _secretPinKey = 'vault_secret_pin';

  /// Attempt to unlock the vault.
  /// If PIN matches general PIN, opens Level 1 (Vault).
  /// If PIN matches secret PIN, opens Level 2 (Secret).
  Future<bool> unlockVault(String pin) async {
    final prefs = await SharedPreferences.getInstance();

    final generalPin = prefs.getString(_generalPinKey);
    final secretPin = prefs.getString(_secretPinKey);

    if (pin == secretPin && secretPin != null) {
      state = VaultState(unlockedLevel: PrivacyLevel.secret, activeKey: pin);
      return true;
    } else if (pin == generalPin && generalPin != null) {
      state = VaultState(unlockedLevel: PrivacyLevel.vault, activeKey: pin);
      return true;
    }

    return false;
  }

  void lockVault() {
    state = VaultState();
  }

  Future<void> setGeneralPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_generalPinKey, newPin);
  }

  Future<void> setSecretPin(String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_secretPinKey, newPin);
  }

  Future<bool> isVaultConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_generalPinKey);
  }

  Future<bool> isSecretVaultConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_secretPinKey);
  }

  Future<bool> verifyGeneralPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_generalPinKey) == pin;
  }

  Future<bool> verifySecretPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_secretPinKey) == pin;
  }
}

final vaultProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  return VaultNotifier();
});
