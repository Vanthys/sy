import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class GradientPreset {
  final String name;
  final List<String> colors;

  const GradientPreset(this.name, this.colors);
}

const List<GradientPreset> _presets = [
  GradientPreset('Flame', ['#FF512F', '#F09819']),
  GradientPreset('Ocean', ['#2193b0', '#6dd5ed']),
  GradientPreset('Forest', ['#11998e', '#38ef7d']),
  GradientPreset('Sunset', ['#c21500', '#ffc500']),
  GradientPreset('Grape', ['#8E2DE2', '#4A00E0']),
  GradientPreset('Mint', ['#00b09b', '#96c93d']),
  GradientPreset('Default', ['#2196F3', '#2196F3']),
];

class GradientPicker extends StatelessWidget {
  const GradientPicker({
    super.key,
    required this.label,
    required this.currentColors,
    required this.onChanged,
  });

  final String label;
  final List<String>? currentColors;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final activeColors = currentColors ?? ['#2196F3', '#2196F3'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _presets.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              if (index < _presets.length) {
                final preset = _presets[index];
                return _GradientPill(
                  colors: preset.colors,
                  isSelected: _isMatch(preset.colors, activeColors),
                  onTap: () => onChanged(preset.colors),
                  tooltip: preset.name,
                );
              } else {
                // Determine if custom is selected (doesn't match any exact preset)
                final isCustomSelected = !_presets.any(
                  (p) => _isMatch(p.colors, activeColors),
                );
                return _CustomColorButton(
                  currentColors: activeColors,
                  isSelected: isCustomSelected,
                  onChanged: onChanged,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  bool _isMatch(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].toUpperCase() != b[i].toUpperCase()) return false;
    }
    return true;
  }
}

class _GradientPill extends StatelessWidget {
  final List<String> colors;
  final bool isSelected;
  final VoidCallback onTap;
  final String tooltip;

  const _GradientPill({
    required this.colors,
    required this.isSelected,
    required this.onTap,
    required this.tooltip,
  });

  Color _parseHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parsedColors = colors.map(_parseHex).toList();
    if (parsedColors.length == 1) {
      parsedColors.add(parsedColors.first); // fallback for gradient requirement
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: parsedColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: isSelected
                ? Border.all(color: cs.onSurface, width: 3)
                : Border.all(color: cs.outline.withAlpha(50), width: 1),
          ),
        ),
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  final List<String> currentColors;
  final bool isSelected;
  final ValueChanged<List<String>> onChanged;

  const _CustomColorButton({
    required this.currentColors,
    required this.isSelected,
    required this.onChanged,
  });

  void _showCustomPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return _CustomColorDialog(
          initialColors: currentColors,
          onApply: (newColors) {
            onChanged(newColors);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Custom Gradient',
      child: GestureDetector(
        onTap: () => _showCustomPicker(context),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.surfaceContainerHigh,
            border: isSelected
                ? Border.all(color: cs.onSurface, width: 3)
                : Border.all(color: cs.outline.withAlpha(50), width: 1),
          ),
          child: Icon(
            Icons.tune,
            color: isSelected ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _CustomColorDialog extends StatefulWidget {
  final List<String> initialColors;
  final ValueChanged<List<String>> onApply;

  const _CustomColorDialog({
    required this.initialColors,
    required this.onApply,
  });

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late List<String> _colors;

  @override
  void initState() {
    super.initState();
    _colors = List.from(widget.initialColors);
    if (_colors.isEmpty) _colors = ['#2196F3', '#2196F3'];
    if (_colors.length == 1) _colors.add(_colors.first);
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

  void _editColor(int index) {
    Color currentColor = _parseHex(_colors[index]);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick a color'),
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
                  _colors[index] = _toHex(currentColor);
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _addColor() {
    setState(() {
      _colors.add(_colors.last);
    });
  }

  void _removeColor(int index) {
    if (_colors.length <= 2) return;
    setState(() {
      _colors.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Custom Gradient'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
                gradient: LinearGradient(
                  colors: _colors.map(_parseHex).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gradient Stops (Min 2)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _colors.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: GestureDetector(
                      onTap: () => _editColor(index),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _parseHex(_colors[index]),
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.outlineVariant),
                        ),
                      ),
                    ),
                    title: Text('Stop ${index + 1}'),
                    subtitle: Text(_colors[index]),
                    trailing: _colors.length > 2
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeColor(index),
                            tooltip: 'Remove stop',
                          )
                        : null,
                    onTap: () => _editColor(index),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addColor,
              icon: const Icon(Icons.add),
              label: const Text('Add Color Stop'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onApply(_colors);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
