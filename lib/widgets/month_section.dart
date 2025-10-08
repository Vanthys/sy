import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'tracker_calendar.dart';

class MonthSection extends StatelessWidget {
  const MonthSection({
    super.key,
    required this.monthLabel,
    required this.days,
    this.unitAbbreviation,
    required this.onDayTap,
  });

  final String monthLabel;
  final List<DayData> days;
  final String? unitAbbreviation;
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
  });

  final DayData dayData;
  final String? unitAbbreviation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasData = dayData.amount > 0;
    //final dayNumber = dayData.date.day.toString();
    final tooltip = hasData
        ? '${DateFormat('yyyy-MM-dd').format(dayData.date)} - ${dayData.amount} ${unitAbbreviation ?? 'units'}'
        : DateFormat('yyyy-MM-dd').format(dayData.date);

    final backgroundColor = hasData
        ? dayData.color
        : colorScheme.surfaceBright; 

    final textColor = hasData
        ? colorScheme.onPrimary
        : colorScheme.onSurfaceVariant;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: tooltip,
          child: Center(
            child: Text(
              DateFormat('E').format(dayData.date).toUpperCase(),
              //hasData ?  dayData.amount.toStringAsFixed(0) : "",
              style: TextStyle(
                fontSize: 48,
                fontWeight: hasData ? FontWeight.bold : FontWeight.bold,
                fontFamily: "Bebas Neue",
                color: hasData ? textColor : textColor.withAlpha(50),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
