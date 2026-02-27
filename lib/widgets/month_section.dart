import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sy3/data/database.dart';
import '../utils/color_utils.dart';
import '../logic/tracker_calendar_provider.dart';

class MonthSection extends StatelessWidget {
  const MonthSection({
    super.key,
    required this.monthLabel,
    required this.days,
    this.unitAbbreviation,
    this.streakType,
    this.streakColors,
    required this.onDayTap,
  });

  final String monthLabel;
  final List<DayData> days;
  final String? unitAbbreviation;
  final StreakType? streakType;
  final List<String>? streakColors;
  final ValueChanged<DayData> onDayTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              return _DayBlock(
                dayData: day,
                unitAbbreviation: unitAbbreviation,
                onTap: () => onDayTap(day),
                streakType: streakType,
                streakColors: streakColors,
                columnIndex: index % 7,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({
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
    final tooltip = hasData
        ? '${DateFormat('yyyy-MM-dd').format(dayData.date)} - ${dayData.amount} ${unitAbbreviation ?? 'units'}'
        : DateFormat('yyyy-MM-dd').format(dayData.date);

    final bool inStreak = dayData.inStreak;

    // Calculate gradient colors
    List<Color> gradientColorList;
    if (streakColors == null || streakColors!.isEmpty) {
      gradientColorList = [const Color(0xFF2196F3), const Color(0xFF2196F3)];
    } else {
      gradientColorList = streakColors!
          .map(ColorUtils.parseHexColor)
          .whereType<Color>()
          .toList();
      if (gradientColorList.isEmpty) {
        gradientColorList = [const Color(0xFF2196F3), const Color(0xFF2196F3)];
      }
      if (gradientColorList.length == 1) {
        gradientColorList.add(gradientColorList.first);
      }
    }

    final backgroundColor = hasData
        ? dayData.color
        : (inStreak ? cs.surfaceContainerHighest : cs.surfaceContainerHighest);

    final textColor = hasData ? cs.onSurfaceVariant : cs.onSurfaceVariant;

    // Define border radii conditionally
    final borderRadius = BorderRadius.horizontal(
      left: dayData.isStreakEnd ? const Radius.circular(8) : Radius.zero,
      right: dayData.isStreakStart ? const Radius.circular(8) : Radius.zero,
    );

    final isLeftConnected =
        inStreak && !dayData.isStreakEnd && columnIndex != 0;
    final isRightConnected =
        inStreak && !dayData.isStreakStart && columnIndex != 6;

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
                  colors: gradientColorList,
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
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: borderRadius,
              child: Tooltip(
                message: tooltip,
                waitDuration: const Duration(milliseconds: 500),
                child: Center(
                  child: Text(
                    dayData.date.day.toString(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: inStreak ? FontWeight.w600 : FontWeight.w500,
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
    );
  }
}
