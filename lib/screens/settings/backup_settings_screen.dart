import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../main.dart';
import '../../services/backup_service.dart';
import 'backup_export_screen.dart';
import 'backup_restore_screen.dart';

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
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateBackupPasswordScreen()),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup saved successfully.')),
      );
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return;

    final filePath = file.path;
    if (filePath == null) return;

    if (!context.mounted) return;
    final result = await Navigator.push<BackupRestoreResult>(
      context,
      MaterialPageRoute(
        builder: (_) => RestoreBackupScreen(backupFilePath: filePath),
      ),
    );
    if (result == null || !context.mounted) return;

    final message = result.hasGeneralVault
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
  }
}
