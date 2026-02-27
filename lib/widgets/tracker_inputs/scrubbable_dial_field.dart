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
  bool _isDragging = false;
  bool _canWrapForward = false;
  bool _canWrapBackward = false;
  int _lastIntValue = 0;

  double get totalValue => _baseRotations * widget.maxValue + _value;

  late final AnimationController _hintController;
  late final Animation<double> _leftArrowOpacity;
  late final Animation<double> _rightArrowOpacity;

  @override
  void initState() {
    super.initState();
    // Ensure we start with a rounded value
    final initialValue = widget.value.roundToDouble();
    _baseRotations = (initialValue ~/ widget.maxValue);
    _value = initialValue % widget.maxValue;
    _lastIntValue = initialValue.round();

    _hintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _leftArrowOpacity =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 60),
        ]).animate(
          CurvedAnimation(
            parent: _hintController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeInOutCubic),
          ),
        );

    _rightArrowOpacity =
        TweenSequence([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 60),
        ]).animate(
          CurvedAnimation(
            parent: _hintController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) _hintController.forward();
    });
  }

  @override
  void dispose() {
    _hintController.dispose();
    super.dispose();
  }

  // ---------------- Interaction ----------------

  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
    _hintController.stop();
    HapticFeedback.selectionClick();

    if (_canWrapForward && _value >= widget.maxValue * 0.98) {
      _baseRotations++;
      _value = 0;
      HapticFeedback.mediumImpact();
    } else if (_canWrapBackward && _value <= widget.maxValue * 0.02) {
      if (_baseRotations > 0) {
        _baseRotations--;
        _value = widget.maxValue;
        HapticFeedback.mediumImpact();
      }
    }

    _canWrapForward = false;
    _canWrapBackward = false;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx / 4;
    final newValue = (_value + delta).clamp(0.0, widget.maxValue);
    setState(() => _value = newValue);

    // Always report rounded value to avoid "ghost" decimals breaking streaks
    final intValue = totalValue.round();
    widget.onChanged(intValue.toDouble());

    if (intValue != _lastIntValue) {
      _lastIntValue = intValue;
      HapticFeedback.selectionClick();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      // Snap internal state to the rounded value on release
      final snapped = totalValue.roundToDouble();
      _baseRotations = (snapped ~/ widget.maxValue);
      _value = snapped % widget.maxValue;
    });

    if (_value >= widget.maxValue * 0.98) {
      _canWrapForward = true;
    } else if (_value <= widget.maxValue * 0.02) {
      _canWrapBackward = true;
    } else {
      _canWrapForward = false;
      _canWrapBackward = false;
    }
  }

  void _increment() {
    setState(() {
      // Ensure we increment from a rounded base
      final newTotal = (totalValue.roundToDouble() + 1);
      _baseRotations = (newTotal ~/ widget.maxValue);
      _value = newTotal % widget.maxValue;
    });
    widget.onChanged(totalValue.roundToDouble());
    HapticFeedback.lightImpact();
  }

  void _decrement() {
    setState(() {
      // Ensure we decrement from a rounded base
      final newTotal = (totalValue.roundToDouble() - 1).clamp(
        0,
        double.infinity,
      );
      _baseRotations = (newTotal ~/ widget.maxValue);
      _value = newTotal % widget.maxValue;
    });
    widget.onChanged(totalValue.roundToDouble());
    HapticFeedback.lightImpact();
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progressFraction = (widget.maxValue == 0)
        ? 0.0
        : (_value / widget.maxValue);

    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: SizedBox(
        width: 380,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // --- Progress ring ---
            CustomPaint(
              size: const Size(220, 220),
              painter: _DialRingPainter(
                progress: progressFraction,
                maxValue: widget.maxValue,
                color: colorScheme.primary,
                trackColor: colorScheme.surfaceContainerHighest,
                isActive: _isDragging,
              ),
            ),

            // --- Center label ---
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

            // --- Left Chevron (outside the ring) ---
            Positioned(
              left: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _decrement,
                child: FadeTransition(
                  opacity: _leftArrowOpacity,
                  child: Icon(
                    Icons.chevron_left,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                    size: 60,
                  ),
                ),
              ),
            ),

            // --- Right Chevron (outside the ring) ---
            Positioned(
              right: 16,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _increment,
                child: FadeTransition(
                  opacity: _rightArrowOpacity,
                  child: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                    size: 60,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialRingPainter extends CustomPainter {
  final double progress;
  final double maxValue;
  final Color color;
  final Color trackColor;
  final bool isActive;

  _DialRingPainter({
    required this.progress,
    required this.maxValue,
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
      ..color = (isActive
          ? color.withValues(alpha: 0.9)
          : color.withValues(alpha: 0.7))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = 0.75 * math.pi;
    final roundBase = 1.5 * math.pi / maxValue;
    var sweepAngle = progress * (math.pi * 1.5);

    sweepAngle = (sweepAngle / roundBase).round() * roundBase;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    // Progress
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  double roundToBase(double number, double base) {
    if (base == 0) return number;

    double scaleFactor = 1e10;
    double scaledNumber = number * scaleFactor;
    double scaledBase = base * scaleFactor;

    return (scaledNumber / scaledBase).round() * scaledBase / scaleFactor;
  }

  @override
  bool shouldRepaint(covariant _DialRingPainter old) {
    return old.progress != progress ||
        old.isActive != isActive ||
        old.color != color ||
        old.trackColor != trackColor;
  }
}
