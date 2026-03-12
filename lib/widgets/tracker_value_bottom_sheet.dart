import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/widgets/tracker_inputs/scrubbable_dial_field.dart';
import '/data/database.dart';
import '/data/tracker_config.dart';

Future<double?> showTrackerValueBottomSheet({
  required BuildContext context,
  required Tracker tracker,
  required DateTime date,
  required double initialAmount,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => TrackerValueBottomSheet(
      tracker: tracker,
      date: date,
      initialAmount: initialAmount,
    ),
  );
}

class TrackerValueBottomSheet extends StatefulWidget {
  const TrackerValueBottomSheet({
    super.key,
    required this.tracker,
    required this.date,
    required this.initialAmount,
  });

  final Tracker tracker;
  final DateTime date;
  final double initialAmount;

  @override
  State<TrackerValueBottomSheet> createState() =>
      _TrackerValueBottomSheetState();
}

class _TrackerValueBottomSheetState extends State<TrackerValueBottomSheet> {
  late double _totalValue;
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _totalValue = widget.initialAmount;
    _controller = TextEditingController(
      text: _totalValue > 0 ? _formatValue(_totalValue) : '',
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
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
        ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom, top: 16),
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
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 24),
            _buildSelector(context),
            const SizedBox(height: 32),

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
                    onPressed: () =>
                        Navigator.pop(context, _totalValue.roundToDouble()),
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

  Widget _buildSelector(BuildContext context) {
    final config = widget.tracker.config;

    switch (config.inputType) {
      case InputType.toggle:
        return Center(
          child: SegmentedButton<double>(
            segments: const [
              ButtonSegment(
                value: 0.0,
                label: Text('No'),
                icon: Icon(Icons.close),
              ),
              ButtonSegment(
                value: 1.0,
                label: Text('Yes'),
                icon: Icon(Icons.check),
              ),
            ],
            selected: {_totalValue},
            onSelectionChanged: (newSelection) {
              setState(() {
                _totalValue = newSelection.first;
              });
            },
          ),
        );

      case InputType.choice:
        final options = config.options ?? ['Option 1', 'Option 2'];
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: List.generate(options.length, (index) {
            final value = (index + 1).toDouble();
            final isSelected = _totalValue == value;
            return ChoiceChip(
              label: Text(options[index]),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _totalValue = selected ? value : 0.0;
                });
              },
            );
          }),
        );

      case InputType.number:
      default:
        return Center(
          child: ScrubbableDialField(
            value: widget.initialAmount,
            maxValue: config.intensityGoal ?? config.maxValue ?? 12,
            unitName: config.unit ?? 'units',
            onChanged: (newTotal) {
              setState(() {
                _totalValue = newTotal;
              });
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 200), () {
                _controller.text = _formatValue(newTotal);
              });
            },
          ),
        );
    }
  }
}
