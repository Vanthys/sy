import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

/// Call this function to show the bottom sheet from anywhere:
///
/// ```dart
/// final result = await showTrackerValueBottomSheet(
///   context: context,
///   date: DateTime.now(),
///   initialAmount: 12,
///   unitName: 'reps',
///   maxValue: 100,
/// );
/// if (result != null) {
///   // save the result
/// }
/// ```
Future<double?> showTrackerValueBottomSheet({
  required BuildContext context,
  required DateTime date,
  required double initialAmount,
  required String unitName,
  double maxValue = 100,
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
  });

  final DateTime date;
  final double initialAmount;
  final String unitName;
  final double maxValue;

  @override
  State<TrackerValueBottomSheet> createState() =>
      _TrackerValueBottomSheetState();
}

class _TrackerValueBottomSheetState extends State<TrackerValueBottomSheet> {
  late double _value;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _value = widget.initialAmount % widget.maxValue;
    _controller = TextEditingController(
      text: _value > 0
          ? _value.toStringAsFixed(
              _value.truncateToDouble() == _value ? 0 : 1,
            )
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateValue(double newValue) {
    final wrapped = newValue % widget.maxValue;
    setState(() {
      _value = wrapped;
      _controller.text = wrapped.toStringAsFixed(
        wrapped.truncateToDouble() == wrapped ? 0 : 1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardInsets = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        bottom: keyboardInsets,
        left: 24,
        right: 24,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- HEADER ---
          Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: colorScheme.outline.withOpacity(0.4),
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

          // --- CIRCULAR DIAL ---
          SleekCircularSlider(
            min: 0,
            max: widget.maxValue,
            initialValue: _value,
            onChange: _updateValue,
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
                trackColor: colorScheme.surfaceVariant,
                progressBarColor: colorScheme.primary,
                dotColor: colorScheme.secondary,
              ),
              infoProperties: InfoProperties(
                mainLabelStyle: Theme.of(context).textTheme.headlineMedium,
                modifier: (double value) {
                  final wrapped = (value % widget.maxValue).round();
                  return '$wrapped ${widget.unitName}';
                },
              ),
            ),
          ),

          const SizedBox(height: 24),

          // --- OPTIONAL TEXT FIELD ---
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
              final parsed = double.tryParse(text);
              if (parsed != null) {
                _updateValue(parsed);
              }
            },
          ),

          const SizedBox(height: 24),

          // --- ACTION BUTTONS ---
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
                  onPressed: () => Navigator.pop(context, _value),
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
    );
  }
}
