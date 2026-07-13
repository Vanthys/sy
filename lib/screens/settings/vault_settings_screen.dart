import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../logic/vault_provider.dart';
import '../../widgets/verify_pin_dialog.dart';
import 'vault_pin_screen.dart';

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

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VaultPinScreen(isSecret: isSecret, isConfigured: isConfigured),
      ),
    );

    if (saved == true) {
      await _checkVaultStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vault passphrase saved successfully.')),
        );
      }
    }
  }

  Future<bool> _verifyPinForAction(bool isSecret) async {
    if (ref.read(vaultProvider).isVaultUnlocked) return true;

    final pin = await VerifyPinDialog.show(
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
