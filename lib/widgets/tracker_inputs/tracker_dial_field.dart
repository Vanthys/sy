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

class _TrackerDialFieldState extends State<TrackerDialField>
    with SingleTickerProviderStateMixin {
  late double _value;
  int _baseRotations = 0;
  double _previousValue = 0;

  double get totalValue => _baseRotations * widget.maxValue + _value;

  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _baseRotations = (widget.value ~/ widget.maxValue);
    _value = widget.value % widget.maxValue;
    _previousValue = _value;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double newValue) {
    _animation = Tween<double>(begin: _value, end: newValue).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(() {
        setState(() {
          _value = _animation.value;
        });
        widget.onChanged(totalValue);
      });

    _controller.forward(from: 0);
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

  void _handleHorizontalDrag(DragUpdateDetails details) {
    // Positive delta.dx = rightward drag → increase
    final delta = details.delta.dx / 4; // adjust sensitivity here
    double newValue = (_value + delta).clamp(0, widget.maxValue);
    _handleChange(newValue);
  }

  void _handleDragEnd(DragEndDetails details) {
    // Optional momentum on fling
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() > 300) {
      final fling = _value + (velocity / 1000);
      _animateTo(fling.clamp(0, widget.maxValue));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: GestureDetector(
        onHorizontalDragUpdate: _handleHorizontalDrag,
        onHorizontalDragEnd: _handleDragEnd,
        behavior: HitTestBehavior.translucent,
        child: SizedBox(
          width: 320,
          height: 320,
          child: Center(
            child: SleekCircularSlider(
              min: 0,
              max: widget.maxValue,
              initialValue: _value,
              onChange: (_) {}, // no-op: we handle drag manually
              appearance: CircularSliderAppearance(
                size: 260,
                startAngle: 135,
                angleRange: 270,
                customWidths: CustomSliderWidths(
                  trackWidth: 6,
                  progressBarWidth: 12,
                  handlerSize: 18,
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
