import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/widgets/tracker_inputs/scrubbable_dial_field.dart';

Future<double?> showTrackerValueBottomSheet({
  required BuildContext context,
  required DateTime date,
  required double initialAmount,
  required String unitName,
  double maxValue = 12,
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
  late double _value; // dial position [0..maxValue]
  int _baseRotations = 0;
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  double get totalValue => _baseRotations * widget.maxValue + _value;

  @override
  void initState() {
    super.initState();
    _baseRotations = (widget.initialAmount ~/ widget.maxValue);
    _value = (widget.initialAmount % widget.maxValue);
    _controller = TextEditingController(
      text: totalValue > 0 ? _formatValue(totalValue) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }


  String _formatValue(double v) =>
      v.truncateToDouble() == v ? v.toStringAsFixed(0) : v.toStringAsFixed(1);




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
            // --- Handle ---
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: colorScheme.outline.withAlpha(40),
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // --- Date ---
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(widget.date),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

const SizedBox(height: 24),
Center(
  child: ScrubbableDialField(
    value: _value,
    maxValue: widget.maxValue,
    unitName: widget.unitName,
    onChanged: (newTotal) {
      setState(() {
        _baseRotations = (newTotal ~/ widget.maxValue);
        _value = (newTotal % widget.maxValue);
      });
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 200), () {
        _controller.text = _formatValue(newTotal);
      });
    },
  ),
),
const SizedBox(height: 24),



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
