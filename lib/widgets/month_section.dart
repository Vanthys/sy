import 'package:flutter/material.dart';
import 'package:sy/data/database.dart';
import '../logic/tracker_calendar_provider.dart';
import '../data/tracker_config.dart';

// MonthSection is replaced by SliverGrid in TrackerCalendar for performance

class DayBlock extends StatelessWidget {
  const DayBlock({
    super.key,
    required this.dayData,
    this.unitAbbreviation,
    required this.onTap,
    this.streakType,
    this.streakColors,
    required this.columnIndex,
    this.inputType = InputType.number,
    this.reversed = false,
  });

  final DayData dayData;
  final String? unitAbbreviation;
  final VoidCallback onTap;
  final StreakType? streakType;
  final List<String>? streakColors;
  final int columnIndex;
  final InputType inputType;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasData = dayData.amount > 0;
    final bool inStreak = dayData.inStreak;

    final backgroundColor = hasData
        ? dayData.color
        : cs.surfaceContainerHighest;

    final textColor = cs.onSurfaceVariant;

    // In reversed mode rows go oldest-left -> newest-right, so isStreakEnd
    // (newest day) lands on the right and isStreakStart (oldest) on the left
    // the opposite of the default newest-first layout.
    final capLeft = reversed ? dayData.isStreakStart : dayData.isStreakEnd;
    final capRight = reversed ? dayData.isStreakEnd : dayData.isStreakStart;

    final borderRadius = BorderRadius.horizontal(
      left: capLeft ? const Radius.circular(8) : Radius.zero,
      right: capRight ? const Radius.circular(8) : Radius.zero,
    );

    final isLeftConnected = inStreak && !capLeft && columnIndex != 0;
    final isRightConnected = inStreak && !capRight && columnIndex != 6;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Connecting background layer for streaks
        if (inStreak)
          Positioned(
            left: isLeftConnected ? -2.5 : 0.0,
            right: isRightConnected ? -2.5 : 0.0,
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: LinearGradient(
                  colors: dayData.streakGradient,
                  begin: inputType == InputType.choice
                      ? const FractionalOffset(0.0, 0.0)
                      : FractionalOffset(-columnIndex.toDouble(), 0.0),
                  end: inputType == InputType.choice
                      ? const FractionalOffset(1.0, 0.0)
                      : FractionalOffset(6.0 - columnIndex.toDouble(), 0.0),
                ),
              ),
            ),
          ),

        // Foreground interactive layer
        Positioned.fill(
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              decoration: BoxDecoration(
                color: inStreak ? Colors.transparent : backgroundColor,
                borderRadius: borderRadius,
              ),
              child: Center(
                child: inputType == InputType.toggle && hasData
                    ? Icon(
                        // a logged day on an abstinence tracker is a lapse
                        streakType == StreakType.abstinence
                            ? Icons.close
                            : Icons.check,
                        color: inStreak
                            ? Colors.white.withAlpha(220)
                            : Colors.white,
                        size: 20,
                      )
                    : Text(
                        dayData.date.day.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: inStreak
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: inStreak
                              ? Colors.white.withAlpha(220)
                              : hasData
                              ? textColor
                              : textColor.withAlpha(200),
                        ),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
