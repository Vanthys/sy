import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../logic/vault_provider.dart';
import '../../utils/passphrase_validation.dart';
import '../../widgets/passphrase_field.dart';
import '../../widgets/password_form_scaffold.dart';

/// Sets up or changes a vault passphrase (general or secret). When
/// [isConfigured] is true, a "Current Passphrase" field is included and
/// verified at submit time - so changing a passphrase is a single full-screen
/// flow rather than a separate verify dialog followed by this screen.
/// Also requires a confirmation field and, for the secret vault, enforces
/// that the new passphrase differs from the general vault's.
class VaultPinScreen extends ConsumerStatefulWidget {
  const VaultPinScreen({
    super.key,
    required this.isSecret,
    required this.isConfigured,
  });

  final bool isSecret;
  final bool isConfigured;

  @override
  ConsumerState<VaultPinScreen> createState() => _VaultPinScreenState();
}

class _VaultPinScreenState extends ConsumerState<VaultPinScreen> {
  TextEditingController? _oldPinController;
  late final TextEditingController _pinController;
  late final TextEditingController _confirmController;
  bool _isSubmitting = false;
  bool _useUnlockedVault = false;
  String? _errorText;

  /// The general vault is open, so its key is in memory and the current
  /// passphrase isn't needed to re-encrypt. The secret vault never keeps its key.
  bool get _canUseUnlockedVault {
    if (widget.isSecret || !widget.isConfigured) return false;
    final vault = ref.read(vaultProvider);
    return vault.unlockedLevel == PrivacyLevel.vault && vault.activeKey != null;
  }

  String get _vaultLabel => widget.isSecret ? 'Secret' : 'General';

  String get _title => widget.isConfigured
      ? 'Change $_vaultLabel Passphrase'
      : 'Set Up $_vaultLabel Vault';

  String get _description {
    if (widget.isConfigured) {
      return widget.isSecret
          ? 'Enter your current Secret passphrase, then choose a new one. '
                'It must remain completely different from your General '
                'passphrase.'
          : 'Enter your current General passphrase, then choose a new one.';
    }
    return widget.isSecret
        ? 'Set a Secret Passphrase for your hidden trackers. This MUST be '
              'completely different from your General Passphrase.'
        : 'Set a General Passphrase to protect your standard vault trackers.';
  }

  @override
  void initState() {
    super.initState();
    if (widget.isConfigured) _oldPinController = TextEditingController();
    _pinController = TextEditingController();
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _oldPinController?.dispose();
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      (!widget.isConfigured ||
          _useUnlockedVault ||
          _oldPinController!.text.isNotEmpty) &&
      validatePassphraseLength(_pinController.text) == null &&
      _pinController.text == _confirmController.text;

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final notifier = ref.read(vaultProvider.notifier);
    String? oldPin;

    if (widget.isConfigured && !_useUnlockedVault) {
      oldPin = _oldPinController!.text;
      final isValid = widget.isSecret
          ? await notifier.verifySecretPin(oldPin)
          : await notifier.verifyGeneralPin(oldPin);
      if (!isValid) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _errorText = 'Incorrect current passphrase.';
          });
        }
        return;
      }
    }

    final newPin = _pinController.text;

    if (widget.isSecret) {
      final generalConfigured = await notifier.isVaultConfigured();
      if (generalConfigured && await notifier.verifyGeneralPin(newPin)) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _errorText =
                'Secret passphrase must differ from your General passphrase.';
          });
        }
        return;
      }
    }

    try {
      if (_useUnlockedVault) {
        final key = ref.read(vaultProvider).activeKey;
        if (key == null) {
          setState(() {
            _isSubmitting = false;
            _useUnlockedVault = false;
            _errorText = 'The vault was locked. Enter your current passphrase.';
          });
          return;
        }
        final repo = await ref.read(trackerRepositoryProvider.future);
        await repo.rekeyVaultWithKey(PrivacyLevel.vault, key, newPin);
      } else if (oldPin != null) {
        final repo = await ref.read(trackerRepositoryProvider.future);
        await repo.rekeyVault(
          widget.isSecret ? PrivacyLevel.secret : PrivacyLevel.vault,
          oldPin,
          newPin,
        );
      }

      if (widget.isSecret) {
        await notifier.setSecretPin(newPin);
      } else {
        await notifier.setGeneralPin(newPin);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorText = 'Failed to save passphrase: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PasswordFormScaffold(
      title: _title,
      primaryLabel: widget.isConfigured ? 'Save Changes' : 'Set Up Vault',
      isSubmitting: _isSubmitting,
      onSubmit: _canSubmit ? _submit : null,
      children: [
        Text(_description, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (widget.isConfigured && !_useUnlockedVault) ...[
          PassphraseField(
            controller: _oldPinController!,
            label: 'Current Passphrase',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          if (_canUseUnlockedVault)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _useUnlockedVault = true),
                child: const Text('Forgot it? Use my unlocked vault'),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (_useUnlockedVault) ...[
          Text(
            'Your vault is unlocked, so the current passphrase is not needed.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _useUnlockedVault = false),
              child: const Text('Enter current passphrase instead'),
            ),
          ),
          const SizedBox(height: 8),
        ],
        PassphraseField(
          controller: _pinController,
          label: 'New Passphrase',
          autofocus: !widget.isConfigured,
          errorText: validatePassphraseLength(_pinController.text),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        PassphraseField(
          controller: _confirmController,
          label: 'Confirm New Passphrase',
          errorText:
              _confirmController.text.isNotEmpty &&
                  _confirmController.text != _pinController.text
              ? 'Passphrases do not match'
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
