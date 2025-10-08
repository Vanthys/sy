import 'package:flutter/material.dart';


class TrackerModal extends StatefulWidget {
  const TrackerModal({
    super.key,
    required this.date,
    required this.initialAmount,
    required this.unitName,
    required this.onSave,
    required this.onCancel,
  });

  final DateTime date;
  final double initialAmount;
  final String unitName;
  final ValueChanged<double> onSave;
  final VoidCallback onCancel;

  @override
  State<TrackerModal> createState() => _TrackerModalState();
}

class _TrackerModalState extends State<TrackerModal> {
  late double _value;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _value = widget.initialAmount;
    _controller = TextEditingController(
      text: widget.initialAmount > 0
          ? widget.initialAmount.toStringAsFixed(
              widget.initialAmount.truncateToDouble() == widget.initialAmount
                  ? 0
                  : 2,
            )
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateValue(double v) {
    setState(() {
      _value = v;
      _controller.text = v.toStringAsFixed(
        v.truncateToDouble() == v ? 0 : 2,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    //final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
  children: [
    Slider(
      value: _value.clamp(0, 100), // adjust range as needed
      min: 0,
      max: 100,
      divisions: 100,
      label: '$_value ${widget.unitName}',
      onChanged: _updateValue,
    ),
    Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => _updateValue((_value - 1).clamp(0, double.infinity)),
        ),
        Text(
          '$_value ${widget.unitName}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => _updateValue(_value + 1),
        ),
      ],
    ),
  ],
),
      ),
    );
  }
}
