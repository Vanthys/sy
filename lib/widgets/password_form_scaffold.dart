import 'package:flutter/material.dart';

/// Shared full-screen scaffold for password/PIN entry flows: an AppBar, a
/// scrollable body for form fields, and a bottom-anchored primary button
/// that shows a loading spinner while [isSubmitting] and blocks back
/// navigation meanwhile (these flows rekey the vault or overwrite the
/// database file, so they shouldn't be interrupted mid-write).
class PasswordFormScaffold extends StatelessWidget {
  const PasswordFormScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.primaryLabel,
    required this.onSubmit,
    this.isSubmitting = false,
    this.destructive = false,
  });

  final String title;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback? onSubmit;
  final bool isSubmitting;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSubmitting,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: isSubmitting ? null : onSubmit,
            child: isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(primaryLabel),
          ),
        ),
      ),
    );
  }
}
