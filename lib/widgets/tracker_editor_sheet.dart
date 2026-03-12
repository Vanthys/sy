import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
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
  late final TextEditingController _intensityGoalController;
  late StreakType _streakType;
  late PrivacyLevel _privacyLevel;
  late TrackerConfig _config;
  late List<TextEditingController> _optionControllers;
  late List<String> _optionColors;

  String? _titleError;
  bool _isSubmitting = false;
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

    _intensityGoalController = TextEditingController(
      text: _config.intensityGoal?.toString() ?? '',
    );

    // Initialize controllers from config
    _optionControllers = (_config.options ?? ['Option 1', 'Option 2'])
        .map((opt) => TextEditingController(text: opt))
        .toList();

    _optionColors = List.from(_config.optionColors ?? ['#FF5252', '#4CAF50']);
    while (_optionColors.length < _optionControllers.length) {
      _optionColors.add('#2196F3');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _intensityGoalController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveTracker() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Title is required');
      return;
    }

    setState(() => _isSubmitting = true);

    final parsedGoal = double.tryParse(_intensityGoalController.text.trim());

    // Update config with latest UI values
    final updatedConfig = TrackerConfig(
      inputType: _config.inputType,
      unit: _config.unit,
      intensityColors: _config.intensityColors,
      streakColors: _config.streakColors,
      maxValue: _config.inputType == InputType.choice
          ? _optionControllers.length.toDouble()
          : _config.maxValue,
      options: _config.inputType == InputType.choice
          ? _optionControllers
                .map((c) => c.text.trim())
                .where((t) => t.isNotEmpty)
                .toList()
          : null,
      intensityGoal: _config.inputType == InputType.number ? parsedGoal : null,
      optionColors: _config.inputType == InputType.choice
          ? _optionColors.sublist(0, _optionControllers.length)
          : null,
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

  Color _parseHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  String _toHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  void _pickOptionColor(int index) {
    Color currentColor = _parseHex(_optionColors[index]);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick Option Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: currentColor,
              onColorChanged: (Color color) {
                currentColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            FilledButton(
              child: const Text('Select'),
              onPressed: () {
                setState(() {
                  _optionColors[index] = _toHex(currentColor);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                widget.isEditing ? 'Edit Tracker' : 'New Tracker',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Basic Info Card
              _buildSectionCard(
                context,
                title: 'Basic Details',
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Tracker Name',
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

              // Behavior Card
              _buildSectionCard(
                context,
                title: 'Tracking Behavior',
                children: [
                  const Text('Streak Type'),
                  const SizedBox(height: 8),
                  SegmentedButton<StreakType>(
                    segments: const [
                      ButtonSegment(
                        value: StreakType.continued,
                        label: Text('Continued'),
                        icon: Icon(Icons.trending_up, size: 18),
                      ),
                      ButtonSegment(
                        value: StreakType.abstinence,
                        label: Text('Abstinence'),
                        icon: Icon(Icons.do_not_disturb_alt, size: 18),
                      ),
                    ],
                    selected: {_streakType},
                    onSelectionChanged: (newSel) =>
                        setState(() => _streakType = newSel.first),
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Input Format'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<InputType>(
                    initialValue: _config.inputType,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _config = TrackerConfig(
                            inputType: value,
                            maxValue: _config.maxValue,
                            unit: _config.unit,
                            intensityColors: _config.intensityColors,
                            streakColors: _config.streakColors,
                            options: _config.options,
                            intensityGoal: _config.intensityGoal,
                            optionColors: _config.optionColors,
                          );
                        });
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: InputType.number,
                        child: Text('Numeric Value'),
                      ),
                      DropdownMenuItem(
                        value: InputType.toggle,
                        child: Text('Checkbox (Yes/No)'),
                      ),
                      DropdownMenuItem(
                        value: InputType.choice,
                        child: Text('Multiple Choice'),
                      ),
                    ],
                  ),

                  if (_config.inputType == InputType.number) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _intensityGoalController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Intensity Goal',
                        hintText: 'e.g. 10 (Max intensity color at this value)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],

                  if (_config.inputType == InputType.choice) ...[
                    const SizedBox(height: 16),
                    const Text('Choices'),
                    const SizedBox(height: 8),
                    ...List.generate(_optionControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _pickOptionColor(index),
                              child: Container(
                                width: 36,
                                height: 36,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: _parseHex(_optionColors[index]),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cs.outlineVariant),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _optionControllers[index],
                                decoration: InputDecoration(
                                  labelText: 'Option ${index + 1}',
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_optionControllers.length > 2)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: cs.error,
                                onPressed: () {
                                  setState(() {
                                    _optionControllers
                                        .removeAt(index)
                                        .dispose();
                                    _optionColors.removeAt(index);
                                  });
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _optionControllers.add(TextEditingController());
                          _optionColors.add('#2196F3');
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Choice'),
                    ),
                  ],
                ],
              ),

              if (widget.vaultState.isVaultUnlocked) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'Privacy Level',
                  children: [
                    SegmentedButton<PrivacyLevel>(
                      segments: [
                        const ButtonSegment(
                          value: PrivacyLevel.standard,
                          label: Text('Public'),
                          icon: Icon(Icons.public, size: 18),
                        ),
                        if (widget.vaultState.unlockedLevel.index >=
                            PrivacyLevel.vault.index)
                          const ButtonSegment(
                            value: PrivacyLevel.vault,
                            label: Text('Vault'),
                            icon: Icon(Icons.lock_outline, size: 18),
                          ),
                        if (widget.vaultState.unlockedLevel.index >=
                            PrivacyLevel.secret.index)
                          const ButtonSegment(
                            value: PrivacyLevel.secret,
                            label: Text('Secret'),
                            icon: Icon(Icons.visibility_off, size: 18),
                          ),
                      ],
                      selected: {_privacyLevel},
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      onSelectionChanged: (s) =>
                          setState(() => _privacyLevel = s.first),
                    ),
                    if (_privacyLevel != PrivacyLevel.standard)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Data will be encrypted with your Vault PIN. Make sure a PIN is set in Settings.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],

              if (_config.inputType != InputType.choice) ...[
                const SizedBox(height: 16),
                _buildSectionCard(
                  context,
                  title: 'Visual Theme',
                  children: [
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
                            options: _config.options,
                            intensityGoal: _config.intensityGoal,
                            optionColors: _config.optionColors,
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
                            options: _config.options,
                            intensityGoal: _config.intensityGoal,
                            optionColors: _config.optionColors,
                          );
                        });
                      },
                    ),
                  ],
                ),
              ],
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
                      onPressed: _isSubmitting ? null : _saveTracker,
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
                                  : 'Create Tracker',
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

  Widget _buildSectionCard(
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
