// lib/widgets/tracker_editor_dialog.dart

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../data/database.dart';

class TrackerEditorDialog extends StatefulWidget {
  const TrackerEditorDialog({
    super.key,
    required this.database,
    this.existingTracker,
  });

  /// Database reference
  final AppDatabase database;

  /// If provided → edit mode. If null → create mode.
  final Tracker? existingTracker;

  bool get isEditing => existingTracker != null;

  @override
  State<TrackerEditorDialog> createState() => _TrackerEditorDialogState();
}

class _TrackerEditorDialogState extends State<TrackerEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _unitNameController;
  late final TextEditingController _unitAbbreviationController;
  late StreakType _streakType;

  String? _titleError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingTracker;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description ?? '');
    _unitNameController =
        TextEditingController(text: existing?.unitName ?? '');
    _unitAbbreviationController =
        TextEditingController(text: existing?.unitAbbreviation ?? '');
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
        // 🔧 EDIT existing tracker
        final updated = TrackersCompanion(
          title: Value(title),
          description: Value(_descriptionController.text.trim()),
          streakType: Value(_streakType),
          unitName: Value(_unitNameController.text.trim()),
          unitAbbreviation: Value(_unitAbbreviationController.text.trim()),
        );

        await (widget.database.update(widget.database.trackers)
              ..where((t) => t.id.equals(widget.existingTracker!.id)))
            .write(updated);
      } else {
        // ✨ CREATE new tracker
        await widget.database.into(widget.database.trackers).insert(
              TrackersCompanion.insert(
                title: title,
                description: _descriptionController.text.trim().isEmpty
                    ? const Value.absent()
                    : Value(_descriptionController.text.trim()),
                streakType: _streakType,
                unitName: _unitNameController.text.trim().isEmpty
                    ? const Value.absent()
                    : Value(_unitNameController.text.trim()),
                unitAbbreviation: _unitAbbreviationController.text.trim().isEmpty
                    ? const Value.absent()
                    : Value(_unitAbbreviationController.text.trim()),
              ),
            );
      }

      if (mounted) Navigator.of(context).pop(true);
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

    return AlertDialog(
      title: Text(isEditing ? 'Edit Tracker' : 'New Tracker'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                errorText: _titleError,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_titleError != null) {
                  setState(() => _titleError = null);
                }
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
              value: _streakType,
              decoration: const InputDecoration(
                labelText: 'Streak type',
              ),
              onChanged: (value) {
                if (value != null) setState(() => _streakType = value);
              },
              items: StreakType.values
                  .map(
                    (type) => DropdownMenuItem(
                      value: type,
                      child: Text(
                        type == StreakType.continued
                            ? 'Continued'
                            : 'Abstinence',
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitNameController,
              decoration: const InputDecoration(
                labelText: 'Unit name (optional)',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _unitAbbreviationController,
              decoration: const InputDecoration(
                labelText: 'Unit abbreviation (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _saveTracker,
          child: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
