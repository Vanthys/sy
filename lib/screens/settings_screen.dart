import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../logic/vault_provider.dart';
import '../logic/theme_provider.dart';

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

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      final isar = await ref.read(isarProvider.future);
      final dbPath = isar.path;
      if (dbPath == null) throw Exception('Isar path is null');
      final file = File(dbPath);

      if (await file.exists()) {
        final box = context.findRenderObject() as RenderBox?;
        final params = ShareParams(
          text: 'tracker database backup',
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
          files: [XFile(dbPath, mimeType: 'application/octet-stream')],
        );
        await SharePlus.instance.share(params);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database file not found!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
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
            title: const Text('Export Database'),
            subtitle: const Text('Backup your trackers and entries locally.'),
            leading: const Icon(Icons.download),
            onTap: () => _exportDatabase(context),
          ),
          const Divider(),
          _buildAppearanceSection(context, ref),
          const Divider(),
          ListTile(
            title: const Text('General Vault Passphrase'),
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
