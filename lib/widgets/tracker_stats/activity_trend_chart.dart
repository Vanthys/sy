import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/database.dart';
import '../../data/tracker_config.dart';
import '../../utils/color_utils.dart';

class ActivityTrendChart extends StatelessWidget {
  const ActivityTrendChart({
    super.key,
    required this.tracker,
    required this.data,
    required this.accent,
  });

  final Tracker tracker;
  final List<double> data;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (data.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        child: const Text('No history available yet.'),
      );
    }

    final isDiscrete =
        tracker.config.inputType == InputType.toggle ||
        tracker.config.inputType == InputType.choice;

    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 24, right: 16, left: 16, bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: isDiscrete
          ? _buildDiscreteTrendChart(data, accent, cs)
          : _buildContinuousTrendChart(data, accent, cs),
    );
  }

  Widget _buildDiscreteTrendChart(
    List<double> data,
    Color accent,
    ColorScheme cs,
  ) {
    double maxVal = 0;
    for (final val in data) {
      if (val > maxVal) maxVal = val;
    }
    if (maxVal == 0) maxVal = 1;

    final barGroups = List.generate(data.length, (i) {
      final val = data[i];
      Color barColor = accent;
      if (tracker.config.inputType == InputType.choice &&
          tracker.config.optionColors?.isNotEmpty == true) {
        final optionIndex = val.toInt() - 1;
        if (optionIndex >= 0 &&
            optionIndex < tracker.config.optionColors!.length) {
          barColor =
              ColorUtils.parseHexColor(
                tracker.config.optionColors![optionIndex],
              ) ??
              accent;
        }
      } else if (val == 0) {
        barColor = cs.outlineVariant;
      }

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: val,
            color: barColor,
            width: 5,
            borderRadius: BorderRadius.circular(2),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal,
              color: cs.surfaceContainerHighest,
            ),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        alignment: BarChartAlignment.spaceEvenly,
        maxY: maxVal,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => cs.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              String label = rod.toY.toStringAsFixed(0);
              if (tracker.config.inputType == InputType.toggle) {
                label = rod.toY > 0 ? 'Done' : 'Skipped';
              } else if (tracker.config.inputType == InputType.choice) {
                final idx = rod.toY.toInt() - 1;
                if (tracker.config.options != null &&
                    idx >= 0 &&
                    idx < tracker.config.options!.length) {
                  label = tracker.config.options![idx];
                } else if (rod.toY == 0) {
                  label = 'Skipped';
                }
              }
              return BarTooltipItem(
                label,
                TextStyle(
                  color: cs.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildContinuousTrendChart(
    List<double> data,
    Color accent,
    ColorScheme cs,
  ) {
    final spots = <FlSpot>[];
    double maxVal = 0;
    for (int i = 0; i < data.length; i++) {
      spots.add(FlSpot(i.toDouble(), data[i]));
      if (data[i] > maxVal) maxVal = data[i];
    }
    if (maxVal == 0) maxVal = 1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxVal * 1.2,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => cs.inverseSurface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final valStr = spot.y % 1 == 0
                    ? spot.y.toInt().toString()
                    : spot.y.toStringAsFixed(1);
                final unitStr = tracker.config.unit != null
                    ? ' ${tracker.config.unit}'
                    : '';
                return LineTooltipItem(
                  '$valStr$unitStr',
                  TextStyle(
                    color: cs.onInverseSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: accent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: accent.withValues(alpha: 0.15),
            ),
          ),
        ],
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal / 2 > 0 ? maxVal / 2 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
