import 'package:flutter/material.dart';
import 'package:sy3/data/database.dart';
import '../logic/tracker_calendar_provider.dart';

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
  });

  final DayData dayData;
  final String? unitAbbreviation;
  final VoidCallback onTap;
  final StreakType? streakType;
  final List<String>? streakColors;
  final int columnIndex;

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

    final borderRadius = BorderRadius.horizontal(
      left: dayData.isStreakEnd ? const Radius.circular(8) : Radius.zero,
      right: dayData.isStreakStart ? const Radius.circular(8) : Radius.zero,
    );

    final isLeftConnected =
        inStreak && !dayData.isStreakEnd && columnIndex != 0;
    final isRightConnected =
        inStreak && !dayData.isStreakStart && columnIndex != 6;

    return RepaintBoundary(
      child: Stack(
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
                    begin: FractionalOffset(-columnIndex.toDouble(), 0.0),
                    end: FractionalOffset(6.0 - columnIndex.toDouble(), 0.0),
                  ),
                ),
              ),
            ),

          // Foreground interactive layer
          Positioned.fill(
            child: Material(
              color: inStreak ? Colors.transparent : backgroundColor,
              borderRadius: borderRadius,
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: onTap,
                borderRadius: borderRadius,
                child: Tooltip(
                  message: dayData.tooltip,
                  waitDuration: const Duration(milliseconds: 500),
                  child: Center(
                    child: Text(
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
          ),
        ],
      ),
    );
  }
}
