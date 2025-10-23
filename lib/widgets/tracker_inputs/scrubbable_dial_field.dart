import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class ScrubbableDialField extends StatefulWidget {
  const ScrubbableDialField({
    super.key,
    required this.value,
    required this.maxValue,
    required this.unitName,
    required this.onChanged,
  });

  final double value;
  final double maxValue;
  final String unitName;
  final ValueChanged<double> onChanged;

  @override
  State<ScrubbableDialField> createState() => _ScrubbableDialFieldState();
}

class _ScrubbableDialFieldState extends State<ScrubbableDialField>
    with TickerProviderStateMixin {
  late double _value;
  int _baseRotations = 0;
  double _previousValue = 0;
  bool _isDragging = false;

  double get totalValue => _baseRotations * widget.maxValue + _value;

  late final AnimationController _hintController;
  late final Animation<double> _leftArrowOpacity;
  late final Animation<double> _rightArrowOpacity;

  @override
  void initState() {
    super.initState();
    _baseRotations = (widget.value ~/ widget.maxValue);
    _value = widget.value % widget.maxValue;
    _previousValue = _value;

    // --- Sequential chevron animation ---
    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Left chevron: starts early, ends mid-way
    _leftArrowOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _hintController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
    ));

    // Right chevron: starts later, ends at the very end
    _rightArrowOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(
      parent: _hintController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
    ));

    // Start hint after sheet fully opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted) _hintController.forward();
      });
    });
  }

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
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
    final delta = details.delta.dx / 4; // sensitivity
    double newValue = (_value + delta).clamp(0, widget.maxValue);
    _handleChange(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progressFraction = _value / widget.maxValue;

    return GestureDetector(
      onHorizontalDragStart: (_) {
        setState(() => _isDragging = true);
        _hintController.stop(); // stop hint if user interacts
        HapticFeedback.selectionClick();
      },
      onHorizontalDragUpdate: _handleHorizontalDrag,
      onHorizontalDragEnd: (_) {
        setState(() => _isDragging = false);
      },
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // --- Progress ring ---
            CustomPaint(
              size: const Size(220, 220),
              painter: _DialRingPainter(
                progress: progressFraction,
                color: colorScheme.primary,
                trackColor: colorScheme.surfaceContainerHighest,
                isActive: _isDragging,
              ),
            ),

            // --- Value label + animated chevrons ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: _leftArrowOpacity,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_left,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                      size: 48,
                    ),
                  ),
                ),
                AnimatedScale(
                  duration: const Duration(milliseconds: 120),
                  scale: _isDragging ? 1.1 : 1.0,
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 120),
                    style: textTheme.headlineMedium!.copyWith(
                      color: _isDragging
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    child: Text('${totalValue.round()} ${widget.unitName}'),
                  ),
                ),
                FadeTransition(
                  opacity: _rightArrowOpacity,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                      size: 48,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final bool isActive;

  _DialRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2.4;
    const strokeWidth = 10.0;

    final trackPaint = Paint()
      ..color = trackColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = isActive ? color : color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Start angle = 0.75π (around 135°)
    const startAngle = 0.75 * math.pi;
    final sweepAngle = progress * (math.pi * 1.5); // 270° sweep

    // Draw background
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    // Draw progress
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DialRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isActive != isActive ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
