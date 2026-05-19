import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../logic/vault_provider.dart';
import '../logic/theme_provider.dart';
import '../services/backup_service.dart';
import '../services/vault_storage_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _generalPinController = TextEditingController();
  final _secretPinController = TextEditingController();
  bool _isVaultConfigured = false;
  bool _isSecretConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkVaultStatus();
  }

  @override
  void dispose() {
    _generalPinController.dispose();
    _secretPinController.dispose();
    super.dispose();
  }

  Future<void> _checkVaultStatus() async {
    final notifier = ref.read(vaultProvider.notifier);
    final isConfigured = await notifier.isVaultConfigured();
    final isSecretConfigured = await notifier.isSecretVaultConfigured();

    if (mounted) {
      setState(() {
        _isVaultConfigured = isConfigured;
        _isSecretConfigured = isSecretConfigured;
      });
    }
  }

  Future<void> _exportBackup(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? fieldError;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Encrypted Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set a password to encrypt your backup. You will need this exact password to restore it — it cannot be recovered if lost.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Backup Password'),
                onChanged: (_) => setDialogState(() => fieldError = null),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  errorText: fieldError,
                ),
                onChanged: (_) => setDialogState(() => fieldError = null),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (passwordController.text.isEmpty) {
                  setDialogState(() => fieldError = 'Password cannot be empty');
                  return;
                }
                if (passwordController.text != confirmController.text) {
                  setDialogState(() => fieldError = 'Passwords do not match');
                  return;
                }
                Navigator.pop(ctx, passwordController.text);
              },
              child: const Text('Create Backup'),
            ),
          ],
        ),
      ),
    );

    if (password == null) return;

    try {
      final isar = await ref.read(isarProvider.future);
      if (!mounted) return;

      final dbPath = isar.path;
      if (dbPath == null) throw Exception('Isar path is null');

      final vaultStorage = ref.read(vaultStorageServiceProvider);
      final backupPath = await BackupService().createBackup(
        isarPath: dbPath,
        password: password,
        vaultStorage: vaultStorage,
      );

      if (!context.mounted) return;

      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
          files: [XFile(backupPath, mimeType: 'application/octet-stream')],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.single.path;
    if (filePath == null) return;

    final passwordController = TextEditingController();

    if (!context.mounted) return;
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the backup password to decrypt and restore.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Backup Password'),
              onSubmitted: (val) => Navigator.pop(ctx, val),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, passwordController.text),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (password == null || password.isEmpty) return;

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Overwrite Current Data?'),
        content: const Text(
          'This will replace all current trackers and entries with the backup. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
          : 'Backup restored. Please restart the app.';

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Complete'),
          content: Text(message),
          actions: [
            FilledButton(
              onPressed: () => exit(0),
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

  Future<void> _setupPin(bool isSecret) async {
    final isConfigured = isSecret ? _isSecretConfigured : _isVaultConfigured;

    if (isConfigured) {
      final oldPinController = TextEditingController();
      final verified = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Text('Verify Current Passphrase'),
          content: TextField(
            controller: oldPinController,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Current Passphrase'),
            onSubmitted: (val) => Navigator.pop(context, true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Verify'),
            ),
          ],
        ),
      );

      if (verified != true) return;

      final oldPin = oldPinController.text;
      final notifier = ref.read(vaultProvider.notifier);
      final isValid = isSecret
          ? await notifier.verifySecretPin(oldPin)
          : await notifier.verifyGeneralPin(oldPin);

      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect current passphrase.')),
          );
        }
        return;
      }

      _showNewPinDialog(isSecret, oldPin: oldPin);
    } else {
      _showNewPinDialog(isSecret);
    }
  }

  Future<bool> _verifyPinForAction(bool isSecret) async {
    // If the Vault is already unlocked, we can trust the user for non-destructive preference toggles
    // like turning on/off biometrics or screen protection, saving them exactly one password entry.
    // Changing the password still uses _setupPin which explicitly requires the old string.
    if (ref.read(vaultProvider).isVaultUnlocked) {
      return true;
    }

    final oldPinController = TextEditingController();
    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Verify Passphrase'),
        content: TextField(
          controller: oldPinController,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Current Passphrase'),
          onSubmitted: (val) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (verified != true) return false;

    final oldPin = oldPinController.text;
    final notifier = ref.read(vaultProvider.notifier);
    final isValid = isSecret
        ? await notifier.verifySecretPin(oldPin)
        : await notifier.verifyGeneralPin(oldPin);

    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Incorrect passphrase.')));
      }
      return false;
    }

    return true;
  }

  Future<void> _showNewPinDialog(bool isSecret, {String? oldPin}) async {
    final controller = isSecret ? _secretPinController : _generalPinController;
    controller.clear();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(isSecret ? 'Setup Secret Vault' : 'Setup General Vault'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSecret
                    ? 'Set a Secret Passphrase for your hidden trackers. This MUST be completely different from your General Passphrase.'
                    : 'Set a General Passphrase to protect your standard vault trackers.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'New Passphrase'),
                onSubmitted: (_) => _savePin(
                  controller.text,
                  isSecret,
                  context,
                  oldPin: oldPin,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  _savePin(controller.text, isSecret, context, oldPin: oldPin),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    _checkVaultStatus();
  }

  Future<void> _savePin(
    String input,
    bool isSecret,
    BuildContext dialogContext, {
    String? oldPin,
  }) async {
    if (input.trim().isEmpty) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('Passphrase cannot be empty.')),
      );
      return;
    }

    final repo = await ref.read(trackerRepositoryProvider.future);

    if (isSecret) {
      if (oldPin != null) {
        await repo.rekeyVault(PrivacyLevel.secret, oldPin, input);
      }
      await ref.read(vaultProvider.notifier).setSecretPin(input);
    } else {
      if (oldPin != null) {
        await repo.rekeyVault(PrivacyLevel.vault, oldPin, input);
      }
      await ref.read(vaultProvider.notifier).setGeneralPin(input);
    }

    if (dialogContext.mounted) {
      Navigator.pop(dialogContext);
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        const SnackBar(content: Text('Vault Passphrase saved successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Create Backup'),
            subtitle: const Text(
              'Export an encrypted backup of your trackers and entries.',
            ),
            leading: const Icon(Icons.upload),
            onTap: () => _exportBackup(context),
          ),
          ListTile(
            title: const Text('Restore Backup'),
            subtitle: const Text('Import a backup file to restore your data.'),
            leading: const Icon(Icons.download),
            onTap: () => _importBackup(context),
          ),
          const Divider(),
          _buildAppearanceSection(context, ref),
          const Divider(),
          ListTile(
            title: const Text('Vault Passphrase'),
            subtitle: Text(
              _isVaultConfigured
                  ? 'Passphrase is set. Tap to change.'
                  : 'Setup a passphrase to enable Private Trackers.',
            ),
            leading: Icon(
              _isVaultConfigured ? Icons.lock : Icons.lock_open,
              color: _isVaultConfigured
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onTap: () => _setupPin(false),
          ),

          if (_isVaultConfigured)
            SwitchListTile(
              title: const Text('Unlock with Biometrics'),
              subtitle: const Text('Use FaceID/TouchID to unlock Vault.'),
              value: vaultState.isBiometricsEnabled,
              onChanged: (val) async {
                // Require password verification before enabling OR disabling biometrics
                final isAuthorized = await _verifyPinForAction(false);
                if (isAuthorized && mounted) {
                  ref.read(vaultProvider.notifier).toggleBiometrics(val);
                }
              },
              secondary: const Icon(Icons.fingerprint),
            ),

          if (_isVaultConfigured)
            SwitchListTile(
              title: const Text('Prevent Screenshots & App Switcher'),
              subtitle: const Text(
                'When the vault is unlocked, block the OS from taking screenshots or app switcher snapshots.',
              ),
              value: vaultState.isScreenProtectionEnabled,
              onChanged: (val) async {
                final isAuthorized = await _verifyPinForAction(false);
                if (isAuthorized && mounted) {
                  ref.read(vaultProvider.notifier).toggleScreenProtection(val);
                }
              },
              secondary: const Icon(Icons.screen_lock_portrait),
            ),

          // Only show secret vault option if they have actively unlocked the vault
          if (vaultState.isVaultUnlocked)
            ListTile(
              title: const Text('Secret Vault Passphrase'),
              subtitle: Text(
                _isSecretConfigured
                    ? 'Secret passphrase is set. Tap to change.'
                    : 'Setup a decoy passphrase for extreme privacy.',
              ),
              leading: Icon(
                _isSecretConfigured ? Icons.visibility_off : Icons.visibility,
                color: _isSecretConfigured
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onTap: () => _setupPin(true),
            ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Appearance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('App Theme'),
            subtitle: const Text('Choose your preferred color scheme.'),
            trailing: DropdownButton<AppThemeMode>(
              value: currentTheme,
              underline: const SizedBox.shrink(),
              items: AppThemeMode.values.map((mode) {
                String label = '';
                switch (mode) {
                  case AppThemeMode.light:
                    label = 'Light';
                    break;
                  case AppThemeMode.dark:
                    label = 'Dark';
                    break;
                  case AppThemeMode.system:
                    label = 'System';
                    break;
                  case AppThemeMode.amoled:
                    label = 'AMOLED';
                    break;
                }
                return DropdownMenuItem(value: mode, child: Text(label));
              }).toList(),
              onChanged: (mode) {
                if (mode != null) {
                  ref.read(themeProvider.notifier).setTheme(mode);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
