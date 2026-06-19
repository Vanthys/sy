import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sy/services/backup_service.dart';
import 'package:sy/services/vault_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File fakeDb;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('backup_test_');
    fakeDb = File('${tempDir.path}/default.isar');
    await fakeDb.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);
  });

  tearDown(() => tempDir.delete(recursive: true));

  Future<VaultStorageService> makeVaultStorage({
    Map<String, String> secure = const {},
  }) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(Map.of(secure));
    return VaultStorageService(await SharedPreferences.getInstance());
  }

  const fullSecure = {
    'vault_general_hash': 'generalHash==',
    'vault_general_salt': 'generalSalt==',
    'vault_general_enc_key': 'generalKey==',
    'vault_secret_hash': 'secretHash==',
    'vault_secret_salt': 'secretSalt==',
  };

  group('BackupService.createBackup', () {
    test('returns path to a non-empty file', () async {
      final storage = await makeVaultStorage(secure: fullSecure);
      final path = await BackupService().createBackup(
        isarPath: fakeDb.path,
        password: 'test-pass',
        vaultStorage: storage,
        outputDir: tempDir,
      );
      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(await file.length(), greaterThan(0));
    });

    test(
      'output is encrypted — vault keys are not readable in plaintext',
      () async {
        final storage = await makeVaultStorage(secure: fullSecure);
        final path = await BackupService().createBackup(
          isarPath: fakeDb.path,
          password: 'test-pass',
          vaultStorage: storage,
          outputDir: tempDir,
        );
        final content = await File(path).readAsString();
        expect(content, isNot(contains('vault_config')));
        expect(content, isNot(contains('generalHash')));
        expect(content, isNot(contains('default.isar')));
      },
    );

    test('same inputs produce different ciphertexts (random IV)', () async {
      final storage = await makeVaultStorage(secure: fullSecure);
      final path1 = await BackupService().createBackup(
        isarPath: fakeDb.path,
        password: 'pass',
        vaultStorage: storage,
        outputDir: tempDir,
      );
      final path2 = await BackupService().createBackup(
        isarPath: fakeDb.path,
        password: 'pass',
        vaultStorage: storage,
        outputDir: tempDir,
      );
      expect(
        await File(path1).readAsString(),
        isNot(equals(await File(path2).readAsString())),
      );
    });

    test('different passwords produce different ciphertexts', () async {
      final storage = await makeVaultStorage(secure: fullSecure);
      final path1 = await BackupService().createBackup(
        isarPath: fakeDb.path,
        password: 'password-a',
        vaultStorage: storage,
        outputDir: tempDir,
      );
      final path2 = await BackupService().createBackup(
        isarPath: fakeDb.path,
        password: 'password-b',
        vaultStorage: storage,
        outputDir: tempDir,
      );
      expect(
        await File(path1).readAsString(),
        isNot(equals(await File(path2).readAsString())),
      );
    });
  });

  group('BackupService.restoreBackup', () {
    test('round-trip preserves database bytes exactly', () async {
      final original = List<int>.generate(256, (i) => i);
      await fakeDb.writeAsBytes(original);

      final storage = await makeVaultStorage(secure: fullSecure);
      final backupPath = await BackupService().createBackup(
        isarPath: fakeDb.path,
        password: 'mypassword',
        vaultStorage: storage,
        outputDir: tempDir,
      );

      final restoreTarget = '${tempDir.path}/restored.isar';
      final freshStorage = await makeVaultStorage();
      await BackupService().restoreBackup(
        backupPath: backupPath,
        password: 'mypassword',
        targetIsarPath: restoreTarget,
        vaultStorage: freshStorage,
      );

      expect(await File(restoreTarget).readAsBytes(), equals(original));
    });

    test('restores full vault config to secure storage', () async {
      final storage = await makeVaultStorage(secure: fullSecure);
      final backupPath = await BackupService().createBackup(
        isarPath: fakeDb.path,
        password: 'pass',
        vaultStorage: storage,
        outputDir: tempDir,
      );

      final freshStorage = await makeVaultStorage();
      final result = await BackupService().restoreBackup(
        backupPath: backupPath,
        password: 'pass',
        targetIsarPath: '${tempDir.path}/restored.isar',
        vaultStorage: freshStorage,
      );

      expect(result.hasGeneralVault, isTrue);
      expect(result.hasSecretVault, isTrue);
      expect(await freshStorage.readGeneralHash(), 'generalHash==');
      expect(await freshStorage.readGeneralSalt(), 'generalSalt==');
      expect(await freshStorage.readGeneralEncryptionKey(), 'generalKey==');
      expect(await freshStorage.readSecretHash(), 'secretHash==');
      expect(await freshStorage.readSecretSalt(), 'secretSalt==');
    });

    test(
      'hasGeneralVault and hasSecretVault are false when no vault was set',
      () async {
        final storage = await makeVaultStorage(); // no vault keys
        final backupPath = await BackupService().createBackup(
          isarPath: fakeDb.path,
          password: 'pass',
          vaultStorage: storage,
          outputDir: tempDir,
        );

        final freshStorage = await makeVaultStorage();
        final result = await BackupService().restoreBackup(
          backupPath: backupPath,
          password: 'pass',
          targetIsarPath: '${tempDir.path}/restored.isar',
          vaultStorage: freshStorage,
        );

        expect(result.hasGeneralVault, isFalse);
        expect(result.hasSecretVault, isFalse);
      },
    );

    test('wrong password throws an exception', () async {
      final storage = await makeVaultStorage(secure: fullSecure);
      final backupPath = await BackupService().createBackup(
        isarPath: fakeDb.path,
        password: 'correct',
        vaultStorage: storage,
        outputDir: tempDir,
      );

      final freshStorage = await makeVaultStorage();
      expect(
        () => BackupService().restoreBackup(
          backupPath: backupPath,
          password: 'wrong',
          targetIsarPath: '${tempDir.path}/restored.isar',
          vaultStorage: freshStorage,
        ),
        throwsException,
      );
    });

    test('corrupted backup file throws an exception', () async {
      final corrupted = File('${tempDir.path}/bad.sy3backup');
      await corrupted.writeAsString('notvalidencrypteddata:aaaa');

      final storage = await makeVaultStorage();
      expect(
        () => BackupService().restoreBackup(
          backupPath: corrupted.path,
          password: 'any',
          targetIsarPath: '${tempDir.path}/restored.isar',
          vaultStorage: storage,
        ),
        throwsException,
      );
    });

    test(
      'only general vault is restored when secret vault was not set',
      () async {
        final storage = await makeVaultStorage(
          secure: {
            'vault_general_hash': 'generalHash==',
            'vault_general_salt': 'generalSalt==',
            'vault_general_enc_key': 'generalKey==',
          },
        );
        final backupPath = await BackupService().createBackup(
          isarPath: fakeDb.path,
          password: 'pass',
          vaultStorage: storage,
          outputDir: tempDir,
        );

        final freshStorage = await makeVaultStorage();
        final result = await BackupService().restoreBackup(
          backupPath: backupPath,
          password: 'pass',
          targetIsarPath: '${tempDir.path}/restored.isar',
          vaultStorage: freshStorage,
        );

        expect(result.hasGeneralVault, isTrue);
        expect(result.hasSecretVault, isFalse);
        expect(await freshStorage.readGeneralHash(), 'generalHash==');
        expect(await freshStorage.readSecretHash(), isNull);
      },
    );
  });
}
