import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_provider.dart';

part 'vault_storage_service.g.dart';

class VaultFlags {
  const VaultFlags({
    required this.biometricsEnabled,
    required this.screenProtectionEnabled,
  });

  final bool biometricsEnabled;
  final bool screenProtectionEnabled;
}

class VaultStorageService {
  VaultStorageService(
    this._prefs, {
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const biometricsEnabledKey = 'vault_biometrics_enabled';
  static const screenProtectionEnabledKey =
      'vault_screen_protection_enabled';
  static const secureGeneralHashRawKey = 'vault_general_hash';
  static const secureGeneralSaltRawKey = 'vault_general_salt';
  static const secureGeneralEncryptionKey = 'vault_general_enc_key';
  static const secureSecretHashRawKey = 'vault_secret_hash';
  static const secureSecretSaltRawKey = 'vault_secret_salt';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  VaultFlags loadFlags() {
    return VaultFlags(
      biometricsEnabled: _prefs.getBool(biometricsEnabledKey) ?? false,
      screenProtectionEnabled:
          _prefs.getBool(screenProtectionEnabledKey) ?? false,
    );
  }

  Future<void> setBiometricsEnabled(bool enable) async {
    await _prefs.setBool(biometricsEnabledKey, enable);
  }

  Future<void> setScreenProtectionEnabled(bool enable) async {
    await _prefs.setBool(screenProtectionEnabledKey, enable);
  }

  Future<void> writeGeneralPin({
    required String hashBase64,
    required String saltBase64,
    required String encryptionKeyBase64,
  }) async {
    await _secureStorage.write(
      key: secureGeneralHashRawKey,
      value: hashBase64,
    );
    await _secureStorage.write(
      key: secureGeneralSaltRawKey,
      value: saltBase64,
    );
    await _secureStorage.write(
      key: secureGeneralEncryptionKey,
      value: encryptionKeyBase64,
    );
  }

  Future<void> writeSecretPin({
    required String hashBase64,
    required String saltBase64,
  }) async {
    await _secureStorage.write(key: secureSecretHashRawKey, value: hashBase64);
    await _secureStorage.write(key: secureSecretSaltRawKey, value: saltBase64);
  }

  Future<bool> hasGeneralPin() {
    return _secureStorage.containsKey(key: secureGeneralHashRawKey);
  }

  Future<bool> hasSecretPin() {
    return _secureStorage.containsKey(key: secureSecretHashRawKey);
  }

  Future<String?> readGeneralHash() {
    return _secureStorage.read(key: secureGeneralHashRawKey);
  }

  Future<String?> readGeneralSalt() {
    return _secureStorage.read(key: secureGeneralSaltRawKey);
  }

  Future<String?> readGeneralEncryptionKey() {
    return _secureStorage.read(key: secureGeneralEncryptionKey);
  }

  Future<String?> readSecretHash() {
    return _secureStorage.read(key: secureSecretHashRawKey);
  }

  Future<String?> readSecretSalt() {
    return _secureStorage.read(key: secureSecretSaltRawKey);
  }
}

@Riverpod(keepAlive: true)
VaultStorageService vaultStorageService(Ref ref) {
  return VaultStorageService(ref.watch(sharedPreferencesProvider));
}
