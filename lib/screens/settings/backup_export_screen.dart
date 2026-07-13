import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../services/backup_service.dart';
import '../../services/vault_storage_service.dart';
import '../../utils/passphrase_validation.dart';
import '../../widgets/passphrase_field.dart';
import '../../widgets/password_form_scaffold.dart';

/// Collects a backup encryption password and, on submit, creates the
/// encrypted backup and lets the user save it - owning the whole operation
/// (rather than just returning the password to the caller) so a loading
/// state can be shown and a failed save doesn't force the user to redo
/// password entry.
class CreateBackupPasswordScreen extends ConsumerStatefulWidget {
  const CreateBackupPasswordScreen({super.key});

  @override
  ConsumerState<CreateBackupPasswordScreen> createState() =>
      _CreateBackupPasswordScreenState();
}

class _CreateBackupPasswordScreenState
    extends ConsumerState<CreateBackupPasswordScreen> {
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmController;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      validatePassphraseLength(_passwordController.text) == null &&
      _passwordController.text == _confirmController.text;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final isar = await ref.read(isarProvider.future);
      final dbPath = isar.path;
      if (dbPath == null) throw Exception('Isar path is null');

      final vaultStorage = ref.read(vaultStorageServiceProvider);
      final backupPath = await BackupService().createBackup(
        isarPath: dbPath,
        password: _passwordController.text,
        vaultStorage: vaultStorage,
      );

      final backupBytes = await File(backupPath).readAsBytes();

      final savePath = await FilePicker.saveFile(
        dialogTitle: 'Save backup',
        fileName: p.basename(backupPath),
        initialDirectory: Platform.isAndroid
            ? '/storage/emulated/0/Download'
            : null,
        bytes: backupBytes,
      );

      if (savePath == null) {
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }
      File(backupPath).deleteSync(recursive: false);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = 'Backup failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PasswordFormScaffold(
      title: 'Create Encrypted Backup',
      primaryLabel: 'Save',
      isSubmitting: _isSubmitting,
      onSubmit: _canSubmit ? _submit : null,
      children: [
        Text(
          'Set a password to encrypt your backup. You will need this exact '
          'password to restore it — it cannot be recovered if lost.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        PassphraseField(
          controller: _passwordController,
          label: 'Password',
          autofocus: true,
          errorText: validatePassphraseLength(_passwordController.text),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        PassphraseField(
          controller: _confirmController,
          label: 'Confirm Password',
          errorText:
              _confirmController.text.isNotEmpty &&
                  _confirmController.text != _passwordController.text
              ? 'Passwords do not match'
              : null,
          onChanged: (_) => setState(() {}),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}
