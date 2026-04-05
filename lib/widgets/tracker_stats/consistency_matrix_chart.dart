import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../logic/tracker_stats_provider.dart';

class ConsistencyMatrixChart extends StatelessWidget {
  const ConsistencyMatrixChart({
    super.key,
    required this.stats,
    required this.accent,
  });

  final TrackerStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxCount = stats.weekdayDistribution.values.fold(
      0,
      (max, v) => v > max ? v : max,
    );

    final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final barGroups = List.generate(7, (i) {
      final val = (stats.weekdayDistribution[i + 1] ?? 0).toDouble();
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: val > 0 ? accent : cs.outlineVariant,
            width: 16,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxCount.toDouble() == 0 ? 1 : maxCount.toDouble(),
              color: cs.surfaceContainerHighest,
            ),
          ),
        ],
      );
    });

    return Container(
      height: 180,
      padding: const EdgeInsets.only(top: 24, right: 16, left: 16, bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxCount.toDouble() == 0 ? 1 : maxCount.toDouble(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => cs.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  rod.toY.toInt().toString(),
                  TextStyle(
                    color: cs.onInverseSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final text = dayNames[value.toInt()];
                  final isWeekend = value == 5 || value == 6;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      text,
                      style: TextStyle(
                        color: isWeekend ? cs.onSurface : cs.onSurfaceVariant,
                        fontWeight: isWeekend
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }
}
