import 'package:flutter/material.dart';

/// Shows a confirmation dialog. Returns true if the user confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Shows a single-field passphrase input dialog. Returns the entered value,
/// or null if dismissed.
Future<String?> showPinInputDialog(
  BuildContext context, {
  required String title,
  String? subtitle,
  String label = 'Passphrase',
  String confirmLabel = 'Confirm',
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) ...[
            Text(subtitle, style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
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
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  // Defer disposal until after the exit animation completes. showDialog()
  // resolves at Navigator.pop() time, before the route finishes animating
  // out. Disposing immediately causes TextField to crash when the overlay
  // rebuilds during the animation (didUpdateWidget re-adds a listener to the
  // disposed controller).
  Future.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}

/// Shows a password-creation dialog with a confirmation field.
/// Returns the chosen password, or null if dismissed/cancelled.
Future<String?> showCreatePasswordDialog(
  BuildContext context, {
  required String title,
  required String description,
  String confirmLabel = 'Save',
}) async {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  String? fieldError;
  void Function(void Function())? setStateRef;

  bool validate() {
    if (passwordController.text.isEmpty) {
      setStateRef?.call(() => fieldError = 'Password cannot be empty');
      return false;
    }
    if (passwordController.text != confirmController.text) {
      setStateRef?.call(() => fieldError = 'Passwords do not match');
      return false;
    }
    return true;
  }

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        setStateRef = setState;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description, style: Theme.of(ctx).textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Password'),
                onChanged: (_) => setState(() => fieldError = null),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  errorText: fieldError,
                ),
                onChanged: (_) => setState(() => fieldError = null),
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
                if (validate()) Navigator.pop(ctx, passwordController.text);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );

  Future.delayed(const Duration(milliseconds: 400), passwordController.dispose);
  Future.delayed(const Duration(milliseconds: 400), confirmController.dispose);
  return result;
}
