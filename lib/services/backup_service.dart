import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

import '../utils/encryption_utils.dart';
import 'vault_storage_service.dart';

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.hasGeneralVault,
    required this.hasSecretVault,
  });

  final bool hasGeneralVault;
  final bool hasSecretVault;
}

class BackupService {
  static const _bundleVersion = 1;
  static const _dbFileName = 'default.isar';
  static const _vaultConfigFileName = 'vault_config.json';

  Future<String> createBackup({
    required String isarPath,
    required String password,
    required VaultStorageService vaultStorage,
    Directory? outputDir,
  }) async {
    final generalHash = await vaultStorage.readGeneralHash();
    final generalSalt = await vaultStorage.readGeneralSalt();
    final generalEncKey = await vaultStorage.readGeneralEncryptionKey();
    final secretHash = await vaultStorage.readSecretHash();
    final secretSalt = await vaultStorage.readSecretSalt();

    final vaultConfig = {
      'version': _bundleVersion,
      'generalHash': generalHash,
      'generalSalt': generalSalt,
      'generalEncKey': generalEncKey,
      'secretHash': secretHash,
      'secretSalt': secretSalt,
    };

    final archive = Archive();

    final dbBytes = await File(isarPath).readAsBytes();
    archive.addFile(ArchiveFile(_dbFileName, dbBytes.length, dbBytes));

    final vaultBytes = utf8.encode(jsonEncode(vaultConfig));
    archive.addFile(
      ArchiveFile(_vaultConfigFileName, vaultBytes.length, vaultBytes),
    );

    final zipBytes = ZipEncoder().encode(archive);

    final key = EncryptionUtils.deriveKeyFromPin(password);
    final encrypted = EncryptionUtils.encryptText(base64Encode(zipBytes), key);

    final tempDir = outputDir ?? await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupFile = File('${tempDir.path}/sy3_backup_$timestamp.sy3backup');
    await backupFile.writeAsString(encrypted);

    return backupFile.path;
  }

  Future<BackupRestoreResult> restoreBackup({
    required String backupPath,
    required String password,
    required String targetIsarPath,
    required VaultStorageService vaultStorage,
  }) async {
    final encrypted = await File(backupPath).readAsString();

    final key = EncryptionUtils.deriveKeyFromPin(password);
    final zipBase64 = EncryptionUtils.decryptText(encrypted, key);

    if (zipBase64 == null) {
      throw Exception('Incorrect backup password or corrupted backup file.');
    }

    final archive = ZipDecoder().decodeBytes(base64Decode(zipBase64));

    final dbFile = archive.findFile(_dbFileName);
    if (dbFile == null) {
      throw Exception('Invalid backup: database file not found.');
    }

    await File(targetIsarPath).writeAsBytes(dbFile.content as List<int>);

    bool hasGeneralVault = false;
    bool hasSecretVault = false;

    final vaultConfigFile = archive.findFile(_vaultConfigFileName);
    if (vaultConfigFile != null) {
      final config =
          jsonDecode(utf8.decode(vaultConfigFile.content as List<int>))
              as Map<String, dynamic>;

      final generalHash = config['generalHash'] as String?;
      final generalSalt = config['generalSalt'] as String?;
      final generalEncKey = config['generalEncKey'] as String?;
      final secretHash = config['secretHash'] as String?;
      final secretSalt = config['secretSalt'] as String?;

      if (generalHash != null && generalSalt != null && generalEncKey != null) {
        await vaultStorage.writeGeneralPin(
          hashBase64: generalHash,
          saltBase64: generalSalt,
          encryptionKeyBase64: generalEncKey,
        );
        hasGeneralVault = true;
      }

      if (secretHash != null && secretSalt != null) {
        await vaultStorage.writeSecretPin(
          hashBase64: secretHash,
          saltBase64: secretSalt,
        );
        hasSecretVault = true;
      }
    }

    return BackupRestoreResult(
      hasGeneralVault: hasGeneralVault,
      hasSecretVault: hasSecretVault,
    );
  }
}
