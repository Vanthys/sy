import 'package:flutter/material.dart';
import '/data/database.dart';
import '/data/tracker_repository.dart';
import '/data/tracker_config.dart';
import 'gradient_picker.dart';

import '/logic/vault_provider.dart';

class TrackerEditorSheet extends StatefulWidget {
  const TrackerEditorSheet({
    super.key,
    required this.repo,
    required this.vaultState,
    this.existingTracker,
  });

  final TrackerRepository repo;
  final VaultState vaultState;
  final Tracker? existingTracker;

  bool get isEditing => existingTracker != null;

  @override
  State<TrackerEditorSheet> createState() => _TrackerEditorSheetState();
}

class _TrackerEditorSheetState extends State<TrackerEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _unitController;
  late final TextEditingController _unitAbbrController;
  late StreakType _streakType;
  late PrivacyLevel _privacyLevel;
  late TrackerConfig _config;

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
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _unitController = TextEditingController();
    _unitAbbrController = TextEditingController();
    _streakType = existing?.streakType ?? StreakType.continued;
    _privacyLevel = existing?.privacyLevel ?? PrivacyLevel.standard;

    // Load existing config or create default one
    _config =
        existing?.config ??
        const TrackerConfig(
          inputType: InputType.number,
          unit: '',
          intensityColors: ['#2196F3', '#2196F3'],
          streakColors: ['#FFC107', '#FF9800'],
        );

    // Initialize controllers from config
    _unitController.text = _config.unit ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _saveTracker() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }

    setState(() => _isSubmitting = true);

    // Update config with latest UI values
    final updatedConfig = TrackerConfig(
      inputType: _config.inputType,
      unit: _unitController.text.trim(),
      intensityColors: _config.intensityColors,
      streakColors: _config.streakColors,
      maxValue: _config.maxValue,
    );

    try {
      if (widget.isEditing) {
        await _repo.updateTracker(
          widget.existingTracker!.id,
          title: title,
          description: _descriptionController.text.trim(),
          streakType: _streakType,
          privacyLevel: _privacyLevel,
          config: updatedConfig,
        );
      } else {
        await _repo.createTracker(
          title: title,
          description: _descriptionController.text.trim(),
          streakType: _streakType,
          privacyLevel: _privacyLevel,
          config: updatedConfig,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save tracker: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                widget.isEditing ? 'Edit Tracker' : 'New Tracker',
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
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
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
              const SizedBox(height: 16),

              if (widget.vaultState.isVaultUnlocked) ...[
                Text(
                  'Privacy',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SegmentedButton<PrivacyLevel>(
                  segments: [
                    const ButtonSegment(
                      value: PrivacyLevel.standard,
                      label: Text('Public'),
                      icon: Icon(Icons.public),
                    ),
                    if (widget.vaultState.unlockedLevel.index >=
                        PrivacyLevel.vault.index)
                      const ButtonSegment(
                        value: PrivacyLevel.vault,
                        label: Text('Vault'),
                        icon: Icon(Icons.lock_outline),
                      ),
                    if (widget.vaultState.unlockedLevel.index >=
                        PrivacyLevel.secret.index)
                      const ButtonSegment(
                        value: PrivacyLevel.secret,
                        label: Text('Secret'),
                        icon: Icon(Icons.visibility_off),
                      ),
                  ],
                  selected: {_privacyLevel},
                  onSelectionChanged: (newSelection) {
                    setState(() => _privacyLevel = newSelection.first);
                  },
                ),
                if (_privacyLevel != PrivacyLevel.standard)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Data will be encrypted with your Vault PIN. Make sure a PIN is set in Settings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
              TextButton.icon(
                onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                icon: Icon(
                  _showAdvanced ? Icons.expand_less : Icons.expand_more,
                ),
                label: Text(
                  _showAdvanced ? 'Hide advanced settings' : 'More options',
                ),
              ),

              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 8),
                    GradientPicker(
                      label: 'Day Intensity Gradient',
                      currentColors: _config.intensityColors,
                      onChanged: (newColors) {
                        setState(() {
                          _config = TrackerConfig(
                            maxValue: _config.maxValue,
                            inputType: _config.inputType,
                            unit: _config.unit,
                            intensityColors: newColors,
                            streakColors: _config.streakColors,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    GradientPicker(
                      label: 'Streak Connect Gradient',
                      currentColors: _config.streakColors,
                      onChanged: (newColors) {
                        setState(() {
                          _config = TrackerConfig(
                            maxValue: _config.maxValue,
                            inputType: _config.inputType,
                            unit: _config.unit,
                            intensityColors: _config.intensityColors,
                            streakColors: newColors,
                          );
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _unitController,
                      decoration: const InputDecoration(labelText: 'Unit name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _unitAbbrController,
                      decoration: const InputDecoration(
                        labelText: 'Unit abbreviation',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'More customization options coming soon…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
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
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(widget.isEditing ? 'Save' : 'Create'),
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
