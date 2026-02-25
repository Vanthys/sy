import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sy3/data/database.dart';

import '../logic/tracker_calendar_provider.dart';

class MonthSection extends StatelessWidget {
  const MonthSection({
    super.key,
    required this.monthLabel,
    required this.days,
    this.unitAbbreviation,
    this.streakType,
    required this.onDayTap,
  });

  final String monthLabel;
  final List<DayData> days;
  final String? unitAbbreviation;
  final StreakType? streakType;
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
  });

  final DayData dayData;
  final String? unitAbbreviation;
  final VoidCallback onTap;
  final StreakType? streakType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasData = dayData.amount > 0;
    final tooltip = hasData
        ? '${DateFormat('yyyy-MM-dd').format(dayData.date)} - ${dayData.amount} ${unitAbbreviation ?? 'units'}'
        : DateFormat('yyyy-MM-dd').format(dayData.date);

    final backgroundColor = hasData
        ? dayData.color
        : cs.surfaceContainerHighest;
    final textColor = hasData ? cs.onSurfaceVariant : cs.onSurfaceVariant;

    final bool inStreak = dayData.inStreak;
    final Color glowColor = streakType == StreakType.abstinence
        ? Colors.lightBlueAccent
        : Colors.orangeAccent;

    return Stack(
      alignment: Alignment.center,
      children: [
        if (inStreak)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),

        Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Tooltip(
              message: tooltip,
              waitDuration: const Duration(milliseconds: 500),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    DateFormat('E').format(dayData.date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 128,
                      fontWeight: FontWeight.w400,
                      fontFamily: "NovaMono",
                      letterSpacing: 1.0,
                      color: inStreak
                          ? glowColor // highlight streak text too
                          : hasData
                          ? textColor
                          : textColor.withValues(alpha: 0.3),
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                  ),
                ),
              ),
            ),
          ),
        ),

        // 🆕 Optional small overlay border (like Duolingo streak badge)
        if (inStreak)
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: glowColor.withValues(alpha: 0.8),
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
