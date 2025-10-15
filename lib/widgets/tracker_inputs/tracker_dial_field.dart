import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

class TrackerDialField extends StatefulWidget {
  const TrackerDialField({
    super.key,
    required this.value,
    required this.maxValue,
    required this.onChanged,
    required this.unitName,
  });

  final double value;
  final double maxValue;
  final String unitName;
  final ValueChanged<double> onChanged;

  @override
  State<TrackerDialField> createState() => _TrackerDialFieldState();
}

class _TrackerDialFieldState extends State<TrackerDialField> {
  late double _value;
  int _baseRotations = 0;
  double _previousValue = 0;

  double get totalValue => _baseRotations * widget.maxValue + _value;

  @override
  void initState() {
    super.initState();
    _baseRotations = (widget.value ~/ widget.maxValue);
    _value = widget.value % widget.maxValue;
    _previousValue = _value;
  }

  void _handleChange(double newValue) {
    const threshold = 0.8;

    if (_previousValue > widget.maxValue * threshold &&
        newValue < widget.maxValue * (1 - threshold)) {
      _baseRotations++;
      HapticFeedback.mediumImpact();
    } else if (_previousValue < widget.maxValue * (1 - threshold) &&
        newValue > widget.maxValue * threshold) {
      if (_baseRotations > 0) _baseRotations--;
      HapticFeedback.selectionClick();
    }

    setState(() {
      _value = newValue;
      _previousValue = newValue;
    });

    widget.onChanged(totalValue);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Expands the interactive zone — feels natural to drag anywhere near the dial
        child: SizedBox(
          width: 320, // increased touch area
          height: 320,
          child: Center(
            child: SleekCircularSlider(
              min: 0,
              max: widget.maxValue,
              initialValue: _value,
              onChange: _handleChange,
              appearance: CircularSliderAppearance(
                size: 260, // visual size (smaller than touch box)
                startAngle: 135,
                angleRange: 270,
                customWidths: CustomSliderWidths(
                  trackWidth: 6,
                  progressBarWidth: 12,
                  handlerSize: 18, // slightly larger knob for easier grab
                ),
                customColors: CustomSliderColors(
                  trackColor: colorScheme.surfaceContainerHighest,
                  progressBarColor: colorScheme.primary,
                  dotColor: colorScheme.secondary,
                ),
                infoProperties: InfoProperties(
                  mainLabelStyle: Theme.of(context).textTheme.headlineMedium,
                  modifier: (_) => '${totalValue.round()} ${widget.unitName}',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
