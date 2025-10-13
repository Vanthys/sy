import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

/// Call this function to show the bottom sheet:
///
/// ```dart
/// final result = await showTrackerValueBottomSheet(
///   context: context,
///   date: DateTime.now(),
///   initialAmount: 12,
///   unitName: 'reps',
///   maxValue: 100,
///   step: 1.0,
/// );
/// if (result != null) {
///   print('User selected: $result');
/// }
/// ```
Future<double?> showTrackerValueBottomSheet({
  required BuildContext context,
  required DateTime date,
  required double initialAmount,
  required String unitName,
  double maxValue = 100,
  double step = 1.0,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => TrackerValueBottomSheet(
      date: date,
      initialAmount: initialAmount,
      unitName: unitName,
      maxValue: maxValue,
      step: step,
    ),
  );
}

class TrackerValueBottomSheet extends StatefulWidget {
  const TrackerValueBottomSheet({
    super.key,
    required this.date,
    required this.initialAmount,
    required this.unitName,
    required this.maxValue,
    required this.step,
  });

  final DateTime date;
  final double initialAmount;
  final String unitName;
  final double maxValue;
  final double step;

  @override
  State<TrackerValueBottomSheet> createState() =>
      _TrackerValueBottomSheetState();
}

class _TrackerValueBottomSheetState extends State<TrackerValueBottomSheet> {
  late double _value; // current dial position [0..maxValue]
  int _baseRotations = 0; // full rotations
  late final TextEditingController _controller;
  bool _isTextUpdating = false;
  double _previousValue = 0;

  double get totalValue => _baseRotations * widget.maxValue + _value;

  @override
  void initState() {
    super.initState();
    // Decompose initial value into rotations + remainder
    _baseRotations = (widget.initialAmount ~/ widget.maxValue);
    _value = (widget.initialAmount % widget.maxValue);
    _controller = TextEditingController(
      text: totalValue > 0
          ? _formatValue(totalValue)
          : '',
    );
    _previousValue = _value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Snap value to nearest step
  double _snap(double val) {
    if (widget.step <= 0) return val;
    return (val / widget.step).round() * widget.step;
  }

  /// Format with no decimals if whole, else 1 decimal
  String _formatValue(double v) {
    return v.truncateToDouble() == v
        ? v.toStringAsFixed(0)
        : v.toStringAsFixed(1);
  }

  void _updateDialValue(double newDialValue) {
    // Snap and clamp within one rotation
    final clamped = _snap(newDialValue.clamp(0, widget.maxValue));

    // Detect rotation crossing
    const double threshold = 0.8;
    if (_previousValue > widget.maxValue * threshold &&
        clamped < widget.maxValue * (1 - threshold)) {
      _baseRotations += 1; // forward wrap
    } else if (_previousValue < widget.maxValue * (1 - threshold) &&
        clamped > widget.maxValue * threshold) {
      if (_baseRotations > 0) _baseRotations -= 1; // reverse wrap
    }

    setState(() {
      _value = clamped;
      _previousValue = clamped;
      if (!_isTextUpdating) {
        _controller.text = _formatValue(totalValue);
      }
    });
  }

  void _updateFromText(double newTotal) {
    final snapped = _snap(newTotal);
    setState(() {
      _baseRotations = (snapped ~/ widget.maxValue);
      _value = (snapped % widget.maxValue);
      _previousValue = _value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24).copyWith(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header ---
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.outline.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(widget.date),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // --- Circular Dial ---
            SleekCircularSlider(
              min: 0,
              max: widget.maxValue,
              initialValue: _value,
              onChange: _updateDialValue,
              appearance: CircularSliderAppearance(
                size: 260,
                startAngle: 150,
                angleRange: 240,
                customWidths: CustomSliderWidths(
                  trackWidth: 6,
                  progressBarWidth: 12,
                  handlerSize: 14,
                ),
                customColors: CustomSliderColors(
                  trackColor: colorScheme.surfaceBright,
                  progressBarColor: colorScheme.primary,
                  dotColor: colorScheme.secondary,
                ),
                infoProperties: InfoProperties(
                  mainLabelStyle: Theme.of(context).textTheme.headlineMedium,
                  modifier: (_) => '${_formatValue(totalValue)} ${widget.unitName}',
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- Manual Text Input ---
            TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Amount (${widget.unitName})',
                hintText: 'Enter manually',
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (text) {
                _isTextUpdating = true;
                final parsed = double.tryParse(text);
                if (parsed != null) {
                  _updateFromText(parsed);
                }
                _isTextUpdating = false;
              },
            ),

            const SizedBox(height: 24),

            // --- Buttons ---
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
                    onPressed: () => Navigator.pop(context, totalValue),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
