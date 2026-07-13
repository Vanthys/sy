import 'package:flutter/material.dart';

import 'passphrase_field.dart';

/// Shows a single-field passphrase input dialog. Returns the entered value,
/// or null if dismissed. The controller is owned by a real State, so it is
/// disposed by the framework only after the dialog route is actually
/// unmounted (i.e. after the exit animation) - no timing hacks needed.
class VerifyPinDialog extends StatefulWidget {
  const VerifyPinDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.label = 'Passphrase',
    this.confirmLabel = 'Confirm',
  });

  final String title;
  final String? subtitle;
  final String label;
  final String confirmLabel;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    String label = 'Passphrase',
    String confirmLabel = 'Confirm',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => VerifyPinDialog(
        title: title,
        subtitle: subtitle,
        label: label,
        confirmLabel: confirmLabel,
      ),
    );
  }

  @override
  State<VerifyPinDialog> createState() => _VerifyPinDialogState();
}

class _VerifyPinDialogState extends State<VerifyPinDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
          PassphraseField(
            controller: _controller,
            label: widget.label,
            autofocus: true,
            onSubmitted: (val) => Navigator.pop(context, val),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
