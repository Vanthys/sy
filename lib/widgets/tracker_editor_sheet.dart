import 'package:flutter/material.dart';
import '/data/database.dart';
import '/data/tracker_repository.dart';

class TrackerEditorSheet extends StatefulWidget {
  const TrackerEditorSheet({
    super.key,
    required this.repo,
    this.existingTracker,
  });

  final TrackerRepository repo;
  final Tracker? existingTracker;

  bool get isEditing => existingTracker != null;

  @override
  State<TrackerEditorSheet> createState() => _TrackerEditorSheetState();
}

class _TrackerEditorSheetState extends State<TrackerEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _unitNameController;
  late final TextEditingController _unitAbbreviationController;
  late StreakType _streakType;

  String? _titleError;
  bool _isSubmitting = false;
  bool _showAdvanced = false;

  late final TrackerRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = widget.repo;

    final existing = widget.existingTracker;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _unitNameController = TextEditingController(text: existing?.unitName ?? '');
    _unitAbbreviationController = TextEditingController(text: existing?.unitAbbreviation ?? '');
    _streakType = existing?.streakType ?? StreakType.continued;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _unitNameController.dispose();
    _unitAbbreviationController.dispose();
    super.dispose();
  }

  Future<void> _saveTracker() async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.isEditing) {
        await _repo.updateTracker(
          widget.existingTracker!.id,
          title: title,
          description: _descriptionController.text.trim(),
          streakType: _streakType,
          unitName: _unitNameController.text.trim(),
          unitAbbreviation: _unitAbbreviationController.text.trim(),
        );
      } else {
        await _repo.createTracker(
          title: title,
          description: _descriptionController.text.trim(),
          streakType: _streakType,
          unitName: _unitNameController.text.trim(),
          unitAbbreviation: _unitAbbreviationController.text.trim(),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save tracker: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withAlpha(50),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Text(
                isEditing ? 'Edit Tracker' : 'New Tracker',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),

              // --- BASIC SETTINGS ---
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  errorText: _titleError,
                ),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_titleError != null) setState(() => _titleError = null);
                },
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<StreakType>(
                initialValue: _streakType,
                decoration: const InputDecoration(labelText: 'Streak type'),
                onChanged: (value) {
                  if (value != null) setState(() => _streakType = value);
                },
                items: const [
                  DropdownMenuItem(
                    value: StreakType.continued,
                    child: Text('Continued'),
                  ),
                  DropdownMenuItem(
                    value: StreakType.abstinence,
                    child: Text('Abstinence'),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              // --- MORE OPTIONS TOGGLE ---
              TextButton.icon(
                onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                icon: Icon(
                  _showAdvanced ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(_showAdvanced ? 'Hide advanced settings' : 'More options'),
              ),

              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 8),
                    TextField(
                      controller: _unitNameController,
                      decoration: const InputDecoration(labelText: 'Unit name'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _unitAbbreviationController,
                      decoration:
                          const InputDecoration(labelText: 'Unit abbreviation'),
                    ),
                    const SizedBox(height: 12),
                    // future icon/color selectors can go here
                    Text(
                      'More customization options coming soon…',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colorScheme.outline),
                    ),
                  ],
                ),
                crossFadeState: _showAdvanced
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _saveTracker,
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(isEditing ? 'Save' : 'Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
