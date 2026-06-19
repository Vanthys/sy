import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../main.dart';
import '../../services/backup_service.dart';
import '../../services/vault_storage_service.dart';
import '../../widgets/app_dialogs.dart';

class BackupSettingsScreen extends ConsumerWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Backup',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Create Backup'),
            subtitle: const Text(
              'Export an encrypted backup of your trackers and entries.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _exportBackup(context, ref),
          ),
          const Divider(indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Restore',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Restore Backup'),
            subtitle: const Text('Import a backup file to restore your data.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _importBackup(context, ref),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Text(
              'Restoring a backup will overwrite all current data and restart the app.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final password = await showCreatePasswordDialog(
      context,
      title: 'Create Encrypted Backup',
      description:
          'Set a password to encrypt your backup. You will need this exact password to restore it — it cannot be recovered if lost.',
    );
    if (password == null) return;

    try {
      final isar = await ref.read(isarProvider.future);
      if (!context.mounted) return;

      final dbPath = isar.path;
      if (dbPath == null) throw Exception('Isar path is null');

      final vaultStorage = ref.read(vaultStorageServiceProvider);
      final backupPath = await BackupService().createBackup(
        isarPath: dbPath,
        password: password,
        vaultStorage: vaultStorage,
      );

      if (!context.mounted) return;

      final backupBytes = await File(backupPath).readAsBytes();

      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save backup',
        fileName: p.basename(backupPath),
        initialDirectory: Platform.isAndroid
            ? '/storage/emulated/0/Download'
            : null,
        bytes: backupBytes,
      );
      if (savePath == null) return;
      File(backupPath).deleteSync(recursive: false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup saved successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;

    final filePath = file.path;
    if (filePath == null) return;

    if (!context.mounted) return;
    final password = await showPinInputDialog(
      context,
      title: 'Restore Backup',
      subtitle: 'Enter the backup password to decrypt and restore.',
      label: 'Backup Password',
      confirmLabel: 'Restore',
    );
    if (password == null || password.isEmpty) return;

    if (!context.mounted) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Overwrite Current Data?',
      body:
          'This will replace all current trackers and entries with the backup. This cannot be undone.',
      confirmLabel: 'Restore',
      destructive: true,
    );
    if (!confirmed) return;

    try {
      final isar = await ref.read(isarProvider.future);
      final dbPath = isar.path;
      if (dbPath == null) throw Exception('Cannot determine database path.');

      await isar.close();

      final vaultStorage = ref.read(vaultStorageServiceProvider);
      final restoreResult = await BackupService().restoreBackup(
        backupPath: filePath,
        password: password,
        targetIsarPath: dbPath,
        vaultStorage: vaultStorage,
      );

      if (!context.mounted) return;

      final message = restoreResult.hasGeneralVault
          ? 'Backup restored. Restart the app, then enter your vault PIN to access your private trackers.'
          : 'Backup restored successfully.';

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Complete'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () {
                // Invalidate isar so it reopens against the restored DB file.
                // Must happen before restartApp so ProviderScope (now outside
                // RestartWidget) keeps its InheritedWidget alive during teardown.
                ref.invalidate(isarProvider);
                Navigator.pop(ctx);
                RestartWidget.restartApp(context);
              },
              child: const Text('Restart App'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }
}
