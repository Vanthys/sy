import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/tracker_config.dart';
import '../../logic/tracker_stats_provider.dart';

class LifecycleTrendChart extends StatelessWidget {
  const LifecycleTrendChart({
    super.key,
    required this.tracker,
    required this.stats,
    required this.accent,
  });

  final Tracker tracker;
  final TrackerStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (stats.lifecycle.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: const Text('No lifecycle data available yet.'),
      );
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.only(top: 16, right: 16, left: 16, bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // room for the first label, which hangs left of its point
          final lead = _rotateLabels ? 52.0 : 14.0;
          final trail = _rotateLabels ? 0.0 : 14.0;
          final needed = stats.lifecycle.bucketLabels.length * _slotWidth;
          final plotWidth = needed > constraints.maxWidth - lead - trail
              ? needed
              : constraints.maxWidth - lead - trail;
          // reverse: starts scrolled to the newest bucket
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: SizedBox(
              width: lead + plotWidth + trail,
              height: constraints.maxHeight,
              child: Padding(
                padding: EdgeInsets.only(left: lead, right: trail),
                child: stats.lifecycle.isStacked
                    ? _buildStackedBarChart(context, cs)
                    : _buildSingleSeriesChart(context, cs),
              ),
            ),
          );
        },
      ),
    );
  }

  static const double _slotWidth = 44;

  // monospace glyphs are ~0.6em wide
  double _labelWidth(String label) => label.length * 11 * 0.6;

  // labels like 'Mar 2026' don't fit a slot flat
  bool get _rotateLabels =>
      stats.lifecycle.bucketLabels.any((label) => label.length > 4);

  Widget _buildSingleSeriesChart(BuildContext context, ColorScheme cs) {
    final values = stats.lifecycle.series.first.values;
    final maxVal = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final maxY = maxVal <= 0 ? 1.0 : maxVal * 1.5;

    if (_usesLineChart) {
      final spots = [
        for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ];

      return LineChart(
        LineChartData(
          minX: 0,
          maxX: (values.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipMargin: 12,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (spot) => cs.inverseSurface,
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final bucket = stats.lifecycle.bucketLabels[spot.x.toInt()];
                  final unit = tracker.config.unit == null
                      ? ''
                      : ' ${tracker.config.unit}';
                  final rawValue = values[spot.x.toInt()];
                  return LineTooltipItem(
                    '$bucket\n${_formatValue(rawValue)}$unit',
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
          titlesData: _titlesData(cs),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      );
    }

    final barGroups = List.generate(values.length, (index) {
      final value = values[index];
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: value > 0 ? accent : cs.outlineVariant,
            width: 18,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal <= 0 ? 1 : maxVal,
              color: cs.surfaceContainerHighest,
            ),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal <= 0 ? 1 : maxVal * 1.5,
        barGroups: barGroups,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipMargin: 12,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (group) => cs.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final bucket = stats.lifecycle.bucketLabels[group.x.toInt()];
              final rawValue = values[group.x.toInt()];
              final unit = tracker.streakType == StreakType.abstinence
                  ? 'lapses'
                  : 'days';
              return BarTooltipItem(
                '$bucket\n${_formatValue(rawValue)} $unit',
                TextStyle(
                  color: cs.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: _titlesData(cs),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  bool get _usesLineChart {
    switch (tracker.config.inputType) {
      case InputType.number:
      case InputType.slider:
      case InputType.timer:
      case InputType.text:
        return !stats.lifecycle.isStacked;
      case InputType.toggle:
      case InputType.choice:
      case InputType.folder:
        return false;
    }
  }

  Widget _buildStackedBarChart(BuildContext context, ColorScheme cs) {
    final bucketCount = stats.lifecycle.bucketLabels.length;
    final maxVal = List.generate(bucketCount, (bucketIndex) {
      return stats.lifecycle.series.fold<double>(
        0,
        (sum, series) => sum + series.values[bucketIndex],
      );
    }).fold<double>(0, (max, total) => total > max ? total : max);

    final barGroups = List.generate(bucketCount, (bucketIndex) {
      final rodStacks = <BarChartRodStackItem>[];
      double start = 0;
      for (
        int seriesIndex = 0;
        seriesIndex < stats.lifecycle.series.length;
        seriesIndex++
      ) {
        final series = stats.lifecycle.series[seriesIndex];
        final value = series.values[bucketIndex];
        if (value <= 0) continue;
        final end = start + value;
        rodStacks.add(
          BarChartRodStackItem(
            start,
            end,
            series.color ?? _fallbackChoiceColor(seriesIndex, cs),
          ),
        );
        start = end;
      }

      return BarChartGroupData(
        x: bucketIndex,
        barRods: [
          BarChartRodData(
            toY: start,
            width: 20,
            rodStackItems: rodStacks,
            borderRadius: BorderRadius.circular(4),
            color: rodStacks.isEmpty ? cs.outlineVariant : null,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal <= 0 ? 1 : maxVal,
              color: cs.surfaceContainerHighest,
            ),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal <= 0 ? 1 : maxVal * 1.5,
        barGroups: barGroups,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipMargin: 12,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (group) => cs.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final bucket = stats.lifecycle.bucketLabels[group.x.toInt()];
              final parts = <String>[];
              for (final series in stats.lifecycle.series) {
                final value = series.values[group.x.toInt()];
                if (value > 0) {
                  parts.add('${series.label}: ${_formatValue(value)}');
                }
              }
              final body = parts.isEmpty ? 'No selections' : parts.join('\n');
              return BarTooltipItem(
                '$bucket\n$body',
                TextStyle(
                  color: cs.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
        titlesData: _titlesData(cs),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  FlTitlesData _titlesData(ColorScheme cs) {
    return FlTitlesData(
      show: true,
      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _rotateLabels ? 60 : 24,
          interval: 1,
          getTitlesWidget: (value, meta) {
            // fl_chart also asks for labels at the axis min/max
            if (value != value.roundToDouble()) return const SizedBox.shrink();
            final index = value.toInt();
            if (index < 0 || index >= stats.lifecycle.bucketLabels.length) {
              return const SizedBox.shrink();
            }
            final label = stats.lifecycle.bucketLabels[index];
            final text = Text(
              label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
            );
            if (!_rotateLabels) {
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: text,
              );
            }
            // rotated about its centre, then shifted so the text ends at its
            // point and hangs down-left clear of the plot
            final w = _labelWidth(label);
            final d = w * 0.7071 / 2;
            return Padding(
              padding: EdgeInsets.only(top: d + 4),
              child: Transform.translate(
                offset: Offset(-d, 0),
                child: Transform.rotate(angle: -math.pi / 4, child: text),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _fallbackChoiceColor(int index, ColorScheme cs) {
    final palette = [
      cs.primary,
      cs.secondary,
      cs.tertiary,
      Colors.orange,
      Colors.teal,
      Colors.redAccent,
    ];
    return palette[index % palette.length];
  }

  String _formatValue(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}
