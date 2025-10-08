import 'package:flutter/material.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

class CircularDial extends StatefulWidget {
  const CircularDial({
    super.key,
    required this.maxValue,
    required this.initialValue,
    required this.onChanged,
    this.unit = '',
  });

  final double maxValue;
  final double initialValue;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  State<CircularDial> createState() => _CircularDialState();
}

class _CircularDialState extends State<CircularDial> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue % widget.maxValue;
  }

  void _handleChange(double newValue) {
    // ✨ Wrap value when it exceeds max
    final wrapped = newValue % widget.maxValue;
    setState(() => _value = wrapped);
    widget.onChanged(wrapped);
  }

  @override
  Widget build(BuildContext context) {
    return SleekCircularSlider(
      min: 0,
      max: widget.maxValue,
      initialValue: _value,
      appearance: CircularSliderAppearance(
        size: 240,
        startAngle: 150,
        angleRange: 240,
        customWidths: CustomSliderWidths(
          trackWidth: 6,
          progressBarWidth: 10,
          handlerSize: 12,
        ),
        customColors: CustomSliderColors(
          trackColor: Theme.of(context).colorScheme.surfaceBright,
          progressBarColor: Theme.of(context).colorScheme.primary,
          dotColor: Theme.of(context).colorScheme.secondary,
        ),
        infoProperties: InfoProperties(
          mainLabelStyle: Theme.of(context).textTheme.headlineMedium,
          modifier: (double value) {
            final rounded = value.round() % widget.maxValue;
            return '$rounded ${widget.unit}';
          },
        ),
      ),
      onChange: _handleChange,
    );
  }
}
