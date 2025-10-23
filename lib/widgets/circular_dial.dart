import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  double? _lastHapticValue;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(0, widget.maxValue);
  }

  void _handleChange(double newValue) {
    // Local UI updates: smooth and immediate
    setState(() => _value = newValue.clamp(0, widget.maxValue));

    // Give tactile feedback at integer steps
    if (_lastHapticValue == null || (newValue - _lastHapticValue!).abs() >= 1) {
      HapticFeedback.selectionClick();
      _lastHapticValue = newValue;
    }
  }

  void _handleChangeEnd(double finalValue) {
    // Debounce: prevent spamming DB while dragging
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), () {
      widget.onChanged(finalValue.clamp(0, widget.maxValue));
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SleekCircularSlider(
      min: 0,
      max: widget.maxValue,
      initialValue: _value,
      onChange: _handleChange,
      onChangeEnd: _handleChangeEnd,
      appearance: CircularSliderAppearance(
        size: 120,
        startAngle: 135,
        angleRange: 270, // wider for smoother rotation
        customWidths: CustomSliderWidths(
          trackWidth: 6,
          progressBarWidth: 12,
          handlerSize: 16, // easier to grab
        ),
        customColors: CustomSliderColors(
          trackColor: theme.colorScheme.onSurfaceVariant,
          progressBarColor: theme.colorScheme.primary,
          dotColor: theme.colorScheme.secondary,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
        infoProperties: InfoProperties(
          mainLabelStyle: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          modifier: (double value) {
            final rounded = value.round().clamp(0, widget.maxValue.toInt());
            return '$rounded ${widget.unit}';
          },
        ),
      ),
    );
  }
}
