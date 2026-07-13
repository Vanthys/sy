import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../services/backup_service.dart';
import '../../services/vault_storage_service.dart';
import '../../widgets/passphrase_field.dart';
import '../../widgets/password_form_scaffold.dart';

/// Merges backup-password entry with the destructive-overwrite confirmation
/// into a single screen: an unmissable warning, the password field, and a
/// required acknowledgment checkbox before the restore can run.
class RestoreBackupScreen extends ConsumerStatefulWidget {
  const RestoreBackupScreen({super.key, required this.backupFilePath});

  final String backupFilePath;

  @override
  ConsumerState<RestoreBackupScreen> createState() =>
      _RestoreBackupScreenState();
}

class _RestoreBackupScreenState extends ConsumerState<RestoreBackupScreen> {
  late final TextEditingController _passwordController;
  bool _acknowledged = false;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _passwordController.text.isNotEmpty && _acknowledged;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final isar = await ref.read(isarProvider.future);
      final dbPath = isar.path;
      if (dbPath == null) throw Exception('Cannot determine database path.');

      final vaultStorage = ref.read(vaultStorageServiceProvider);
      final result = await BackupService().restoreBackup(
        backupPath: widget.backupFilePath,
        password: _passwordController.text,
        targetIsarPath: dbPath,
        vaultStorage: vaultStorage,
        onPasswordValidated: () => isar.close(),
      );

      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = 'Restore failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PasswordFormScaffold(
      title: 'Restore Backup',
      primaryLabel: 'Overwrite & Restore',
      destructive: true,
      isSubmitting: _isSubmitting,
      onSubmit: _canSubmit ? _submit : null,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This will overwrite all current data',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'All current trackers and entries will be permanently '
                      'replaced by this backup. This cannot be undone.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PassphraseField(
          controller: _passwordController,
          label: 'Backup Password',
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _acknowledged,
          onChanged: (val) => setState(() => _acknowledged = val ?? false),
          title: const Text(
            'I understand this will permanently overwrite my current data',
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(_errorText!, style: TextStyle(color: colorScheme.error)),
        ],
      ],
    );
  }
}
