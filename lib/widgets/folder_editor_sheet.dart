import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/data/database.dart';
import '/data/providers.dart';
import '/data/tracker_config.dart';
import '/data/tracker_repository.dart';

class FolderEditorSheet extends ConsumerStatefulWidget {
  const FolderEditorSheet({super.key, required this.repo, this.existingFolder});

  final TrackerRepository repo;
  final Tracker? existingFolder;

  bool get isEditing => existingFolder != null;

  @override
  ConsumerState<FolderEditorSheet> createState() => _FolderEditorSheetState();
}

class _FolderEditorSheetState extends ConsumerState<FolderEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late List<String> _selectedChildIds;
  List<Tracker> _availableTrackers = [];
  String? _titleError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingFolder;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _selectedChildIds = List.from(existing?.childIds ?? []);

    Future.microtask(() async {
      try {
        final trackers = await ref.read(trackerListProvider.future);
        if (mounted) {
          setState(() {
            _availableTrackers = trackers
                .where((t) => !t.isFolder && t.id != existing?.id)
                .toList();
          });
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (widget.isEditing) {
        await widget.repo.updateTracker(
          widget.existingFolder!.id,
          title: title,
          description: _descriptionController.text.trim(),
          childIds: _selectedChildIds,
        );
      } else {
        await widget.repo.createTracker(
          title: title,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          streakType: StreakType.continued,
          config: const TrackerConfig(inputType: InputType.folder),
          childIds: _selectedChildIds,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save folder: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isEditing ? 'Edit Folder' : 'New Folder',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              _buildCard(
                context,
                title: 'Basic Details',
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Folder Name',
                      errorText: _titleError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildCard(
                context,
                title: 'Trackers',
                children: _availableTrackers.isEmpty
                    ? [
                        const Text(
                          'No trackers available.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ]
                    : _availableTrackers.map((t) {
                        final selected = _selectedChildIds.contains(t.id);
                        return CheckboxListTile(
                          value: selected,
                          title: Text(t.title),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedChildIds.add(t.id);
                              } else {
                                _selectedChildIds.remove(t.id);
                              }
                            });
                          },
                        );
                      }).toList(),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isSubmitting ? null : _save,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.isEditing
                                  ? 'Save Changes'
                                  : 'Create Folder',
                            ),
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

  Widget _buildCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withAlpha(100),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withAlpha(100)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
