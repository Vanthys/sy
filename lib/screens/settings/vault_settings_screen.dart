import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../logic/vault_provider.dart';
import '../../widgets/app_dialogs.dart';

class VaultSettingsScreen extends ConsumerStatefulWidget {
  const VaultSettingsScreen({super.key});

  @override
  ConsumerState<VaultSettingsScreen> createState() =>
      _VaultSettingsScreenState();
}

class _VaultSettingsScreenState extends ConsumerState<VaultSettingsScreen> {
  bool _isVaultConfigured = false;
  bool _isSecretConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkVaultStatus();
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

  Future<void> _setupPin(bool isSecret) async {
    final isConfigured = isSecret ? _isSecretConfigured : _isVaultConfigured;

    if (isConfigured) {
      final oldPin = await showPinInputDialog(
        context,
        title: 'Verify Current Passphrase',
        label: 'Current Passphrase',
      );
      if (oldPin == null) return;

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

      await _showNewPinDialog(isSecret, oldPin: oldPin);
    } else {
      await _showNewPinDialog(isSecret);
    }
  }

  Future<bool> _verifyPinForAction(bool isSecret) async {
    if (ref.read(vaultProvider).isVaultUnlocked) return true;

    final pin = await showPinInputDialog(
      context,
      title: 'Verify Passphrase',
      label: 'Current Passphrase',
    );
    if (pin == null) return false;

    final notifier = ref.read(vaultProvider.notifier);
    final isValid = isSecret
        ? await notifier.verifySecretPin(pin)
        : await notifier.verifyGeneralPin(pin);

    if (!isValid && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incorrect passphrase.')));
    }
    return isValid;
  }

  Future<void> _showNewPinDialog(bool isSecret, {String? oldPin}) async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(isSecret ? 'Setup Secret Vault' : 'Setup General Vault'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSecret
                  ? 'Set a Secret Passphrase for your hidden trackers. This MUST be completely different from your General Passphrase.'
                  : 'Set a General Passphrase to protect your standard vault trackers.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'New Passphrase'),
              onSubmitted: (_) =>
                  _savePin(controller.text, isSecret, ctx, oldPin: oldPin),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                _savePin(controller.text, isSecret, ctx, oldPin: oldPin),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
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
        const SnackBar(content: Text('Vault passphrase saved successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Vault')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'General Vault',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              _isVaultConfigured
                  ? Icons.lock_outlined
                  : Icons.lock_open_outlined,
              color: _isVaultConfigured
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            title: const Text('Vault Passphrase'),
            subtitle: Text(
              _isVaultConfigured
                  ? 'Passphrase is set. Tap to change.'
                  : 'Set a passphrase to enable Private Trackers.',
            ),
            onTap: () => _setupPin(false),
          ),
          if (_isVaultConfigured) ...[
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Unlock with Biometrics'),
              subtitle: const Text(
                'Use Face ID / Touch ID to unlock the vault.',
              ),
              value: vaultState.isBiometricsEnabled,
              onChanged: (val) async {
                final ok = await _verifyPinForAction(false);
                if (ok && mounted) {
                  ref.read(vaultProvider.notifier).toggleBiometrics(val);
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.screen_lock_portrait_outlined),
              title: const Text('Prevent Screenshots'),
              subtitle: const Text(
                'Block the OS from taking screenshots or app switcher snapshots while the vault is unlocked.',
              ),
              value: vaultState.isScreenProtectionEnabled,
              onChanged: (val) async {
                final ok = await _verifyPinForAction(false);
                if (ok && mounted) {
                  ref.read(vaultProvider.notifier).toggleScreenProtection(val);
                }
              },
            ),
          ],
          if (vaultState.isVaultUnlocked) ...[
            const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Secret Vault',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ListTile(
              leading: Icon(
                _isSecretConfigured
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _isSecretConfigured
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: const Text('Secret Vault Passphrase'),
              subtitle: Text(
                _isSecretConfigured
                    ? 'Secret passphrase is set. Tap to change.'
                    : 'Set a decoy passphrase for extreme privacy.',
              ),
              onTap: () => _setupPin(true),
            ),
          ],
        ],
      ),
    );
  }
}
