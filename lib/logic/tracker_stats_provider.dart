import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../data/tracker_config.dart';

enum TrackerStatsFamily { numeric, toggle, choice, abstinence }

enum LifecycleGranularity { week, month }

class TrackerStatCard {
  const TrackerStatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
}

class LifecycleSeries {
  const LifecycleSeries({
    required this.label,
    required this.values,
    this.color,
  });

  final String label;
  final List<double> values;
  final Color? color;
}

class LifecycleChartData {
  const LifecycleChartData({
    required this.granularity,
    required this.bucketLabels,
    required this.series,
    required this.isStacked,
  });

  final LifecycleGranularity granularity;
  final List<String> bucketLabels;
  final List<LifecycleSeries> series;
  final bool isStacked;

  bool get isEmpty =>
      bucketLabels.isEmpty ||
      series.every((series) => series.values.every((value) => value <= 0));
}

class ChoiceSummary {
  const ChoiceSummary({
    required this.label,
    required this.count,
    required this.index,
  });

  final String label;
  final int count;
  final int index;
}

class TrackerStats {
  const TrackerStats({
    required this.family,
    required this.overviewCards,
    required this.weekdayDistribution,
    required this.lifecycle,
    required this.currentStreak,
    required this.longestStreak,
    required this.longestStreakStart,
    required this.longestStreakEnd,
    required this.nextMilestone,
    required this.trackingStart,
    required this.totalActiveDays,
    required this.totalQuantity,
    required this.completionRate,
    required this.daysSinceLastLapse,
    required this.optionTotals,
    required this.monthlyOptionTotals,
    required this.topChoice,
    required this.topChoiceThisMonth,
  });

  final TrackerStatsFamily family;
  final List<TrackerStatCard> overviewCards;
  final Map<int, int> weekdayDistribution;
  final LifecycleChartData lifecycle;
  final int currentStreak;
  final int longestStreak;
  final DateTime? longestStreakStart;
  final DateTime? longestStreakEnd;
  final int nextMilestone;
  final DateTime trackingStart;
  final int totalActiveDays;
  final double totalQuantity;
  final double completionRate;
  final int? daysSinceLastLapse;
  final Map<int, int> optionTotals;
  final Map<int, int> monthlyOptionTotals;
  final ChoiceSummary? topChoice;
  final ChoiceSummary? topChoiceThisMonth;
}

class _BucketAccumulator {
  _BucketAccumulator({
    required this.start,
    required this.end,
    required this.label,
  });

  final DateTime start;
  final DateTime end;
  final String label;
  double total = 0;
  final Map<int, int> choiceCounts = <int, int>{};
}

final trackerStatsProvider = StreamProvider.family<TrackerStats, Tracker>((
  ref,
  tracker,
) async* {
  final entryRepo = await ref.watch(entryRepositoryProvider.future);

  yield* entryRepo.watchEntries(tracker.id).map((entries) {
    final meaningfulEntries =
        entries.where((entry) => entry.quantity.round() > 0).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(today.year, today.month, 1);

    final createdAt = tracker.createdAt;
    final createdAtDay = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    final entryDays = meaningfulEntries
        .map(
          (entry) =>
              DateTime(entry.date.year, entry.date.month, entry.date.day),
        )
        .toList();
    final earliestEntry = entryDays.isEmpty ? createdAtDay : entryDays.first;
    final trackingStart = earliestEntry.isBefore(createdAtDay)
        ? earliestEntry
        : createdAtDay;
    final entryDaySet = entryDays.toSet();
    final daysSinceStart = today.difference(trackingStart).inDays + 1;

    final family = _resolveFamily(tracker);
    final totalActiveDays = meaningfulEntries.length;
    final totalQuantity = meaningfulEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.quantity,
    );

    final completionRate = _completionRate(
      streakType: tracker.streakType,
      totalActiveDays: totalActiveDays,
      daysSinceStart: daysSinceStart,
    );

    final weekdayDistribution = _weekdayDistribution(meaningfulEntries);
    final monthlyEntries = meaningfulEntries
        .where(
          (entry) => !DateTime(
            entry.date.year,
            entry.date.month,
            entry.date.day,
          ).isBefore(monthStart),
        )
        .toList();

    final monthlyActiveDays = monthlyEntries.length;
    final monthlyTotal = monthlyEntries.fold<double>(
      0,
      (sum, entry) => sum + entry.quantity,
    );
    final monthlyAverage = monthlyActiveDays == 0
        ? 0.0
        : monthlyTotal / monthlyActiveDays;

    final milestones = [7, 14, 30, 60, 90, 100, 180, 365, 500, 1000];
    final nextMilestone = milestones.firstWhere(
      (milestone) => milestone > tracker.currentStreak,
      orElse: () => ((tracker.currentStreak / 100).floor() + 1) * 100,
    );

    final longest = _computeLongestStreak(
      entryDaySet: entryDaySet,
      trackingStart: trackingStart,
      today: today,
      streakType: tracker.streakType,
    );

    final optionTotals = _optionCounts(meaningfulEntries);
    final monthlyOptionTotals = _optionCounts(monthlyEntries);
    final topChoice = family == TrackerStatsFamily.choice
        ? _resolveTopChoice(tracker, optionTotals)
        : null;
    final topChoiceThisMonth = family == TrackerStatsFamily.choice
        ? _resolveTopChoice(tracker, monthlyOptionTotals)
        : null;

    final daysSinceLastLapse = tracker.streakType == StreakType.abstinence
        ? _daysSinceLastLapse(meaningfulEntries, today)
        : null;

    final lifecycle = _buildLifecycle(
      tracker: tracker,
      entries: meaningfulEntries,
      trackingStart: trackingStart,
      today: today,
    );

    final overviewCards = _buildOverviewCards(
      tracker: tracker,
      family: family,
      totalActiveDays: totalActiveDays,
      totalQuantity: totalQuantity,
      completionRate: completionRate,
      monthlyActiveDays: monthlyActiveDays,
      monthlyAverage: monthlyAverage,
      monthlyEntries: monthlyEntries,
      lifecycle: lifecycle,
      longestStreak: longest.length > tracker.longestStreak
          ? longest.length
          : tracker.longestStreak,
      daysSinceLastLapse: daysSinceLastLapse,
      topChoice: topChoice,
      topChoiceThisMonth: topChoiceThisMonth,
    );

    return TrackerStats(
      family: family,
      overviewCards: overviewCards,
      weekdayDistribution: weekdayDistribution,
      lifecycle: lifecycle,
      currentStreak: tracker.currentStreak,
      longestStreak: longest.length > tracker.longestStreak
          ? longest.length
          : tracker.longestStreak,
      longestStreakStart: longest.start,
      longestStreakEnd: longest.end,
      nextMilestone: nextMilestone,
      trackingStart: trackingStart,
      totalActiveDays: totalActiveDays,
      totalQuantity: totalQuantity,
      completionRate: completionRate,
      daysSinceLastLapse: daysSinceLastLapse,
      optionTotals: optionTotals,
      monthlyOptionTotals: monthlyOptionTotals,
      topChoice: topChoice,
      topChoiceThisMonth: topChoiceThisMonth,
    );
  });
});

TrackerStatsFamily _resolveFamily(Tracker tracker) {
  if (tracker.streakType == StreakType.abstinence) {
    return TrackerStatsFamily.abstinence;
  }

  switch (tracker.config.inputType) {
    case InputType.toggle:
      return TrackerStatsFamily.toggle;
    case InputType.choice:
      return TrackerStatsFamily.choice;
    case InputType.number:
    case InputType.slider:
    case InputType.timer:
    case InputType.text:
    case InputType.folder:
      return TrackerStatsFamily.numeric;
  }
}

double _completionRate({
  required StreakType streakType,
  required int totalActiveDays,
  required int daysSinceStart,
}) {
  if (daysSinceStart <= 0) return 0;
  if (streakType == StreakType.continued) {
    return totalActiveDays / daysSinceStart;
  }
  final cleanDays = daysSinceStart - totalActiveDays;
  return cleanDays <= 0 ? 0 : cleanDays / daysSinceStart;
}

Map<int, int> _weekdayDistribution(List<Entry> entries) {
  final distribution = <int, int>{for (int i = 1; i <= 7; i++) i: 0};
  for (final entry in entries) {
    distribution[entry.date.weekday] =
        (distribution[entry.date.weekday] ?? 0) + 1;
  }
  return distribution;
}

Map<int, int> _optionCounts(List<Entry> entries) {
  final counts = <int, int>{};
  for (final entry in entries) {
    final optionIndex = entry.quantity.toInt() - 1;
    if (optionIndex >= 0) {
      counts[optionIndex] = (counts[optionIndex] ?? 0) + 1;
    }
  }
  return counts;
}

ChoiceSummary? _resolveTopChoice(Tracker tracker, Map<int, int> counts) {
  if (counts.isEmpty) return null;

  int? bestIndex;
  int bestCount = -1;
  for (final entry in counts.entries) {
    if (entry.value > bestCount ||
        (entry.value == bestCount &&
            bestIndex != null &&
            entry.key < bestIndex)) {
      bestIndex = entry.key;
      bestCount = entry.value;
    } else if (entry.value > bestCount && bestIndex == null) {
      bestIndex = entry.key;
      bestCount = entry.value;
    }
  }

  if (bestIndex == null || bestCount <= 0) return null;

  final options = tracker.config.options ?? const <String>[];
  final label = bestIndex < options.length
      ? options[bestIndex]
      : 'Option ${bestIndex + 1}';
  return ChoiceSummary(label: label, count: bestCount, index: bestIndex);
}

int? _daysSinceLastLapse(List<Entry> entries, DateTime today) {
  if (entries.isEmpty) return null;
  final last = entries.last.date;
  final lastDay = DateTime(last.year, last.month, last.day);
  return today.difference(lastDay).inDays;
}

({int length, DateTime? start, DateTime? end}) _computeLongestStreak({
  required Set<DateTime> entryDaySet,
  required DateTime trackingStart,
  required DateTime today,
  required StreakType streakType,
}) {
  int run = 0;
  int maxRun = 0;
  DateTime? runStart;
  DateTime? longestStart;
  DateTime? longestEnd;

  for (
    DateTime day = trackingStart;
    !day.isAfter(today);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    final hasEntry = entryDaySet.contains(day);
    final goodDay = streakType == StreakType.continued ? hasEntry : !hasEntry;

    if (goodDay) {
      runStart ??= day;
      run++;
      if (run > maxRun) {
        maxRun = run;
        longestStart = runStart;
        longestEnd = day;
      }
    } else {
      run = 0;
      runStart = null;
    }
  }

  return (length: maxRun, start: longestStart, end: longestEnd);
}

LifecycleChartData _buildLifecycle({
  required Tracker tracker,
  required List<Entry> entries,
  required DateTime trackingStart,
  required DateTime today,
}) {
  final ageInDays = today.difference(trackingStart).inDays + 1;
  final granularity = ageInDays <= 84
      ? LifecycleGranularity.week
      : LifecycleGranularity.month;

  final buckets = <_BucketAccumulator>[];
  if (granularity == LifecycleGranularity.week) {
    var bucketStart = trackingStart;
    var weekNumber = 1;
    while (!bucketStart.isAfter(today)) {
      final bucketEndCandidate = DateTime(
        bucketStart.year,
        bucketStart.month,
        bucketStart.day + 6,
      );
      final bucketEnd = bucketEndCandidate.isAfter(today)
          ? today
          : bucketEndCandidate;
      buckets.add(
        _BucketAccumulator(
          start: bucketStart,
          end: bucketEnd,
          label: 'W$weekNumber',
        ),
      );
      bucketStart = DateTime(
        bucketEnd.year,
        bucketEnd.month,
        bucketEnd.day + 1,
      );
      weekNumber++;
    }
  } else {
    var cursor = DateTime(trackingStart.year, trackingStart.month, 1);
    while (!cursor.isAfter(today)) {
      final nextMonth = DateTime(cursor.year, cursor.month + 1, 1);
      final bucketEndCandidate = DateTime(
        nextMonth.year,
        nextMonth.month,
        nextMonth.day - 1,
      );
      final bucketStart = cursor.isBefore(trackingStart)
          ? trackingStart
          : cursor;
      final bucketEnd = bucketEndCandidate.isAfter(today)
          ? today
          : bucketEndCandidate;
      buckets.add(
        _BucketAccumulator(
          start: bucketStart,
          end: bucketEnd,
          label: _monthLabel(cursor),
        ),
      );
      cursor = nextMonth;
    }
  }

  for (final entry in entries) {
    final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
    for (final bucket in buckets) {
      final inBucket = !day.isBefore(bucket.start) && !day.isAfter(bucket.end);
      if (!inBucket) continue;

      switch (_resolveFamily(tracker)) {
        case TrackerStatsFamily.numeric:
          bucket.total += entry.quantity;
          break;
        case TrackerStatsFamily.toggle:
        case TrackerStatsFamily.abstinence:
          bucket.total += 1;
          break;
        case TrackerStatsFamily.choice:
          final optionIndex = entry.quantity.toInt() - 1;
          if (optionIndex >= 0) {
            bucket.choiceCounts[optionIndex] =
                (bucket.choiceCounts[optionIndex] ?? 0) + 1;
          }
          break;
      }
      break;
    }
  }

  if (_resolveFamily(tracker) == TrackerStatsFamily.choice) {
    final optionCount =
        tracker.config.options?.length ??
        buckets
            .expand((bucket) => bucket.choiceCounts.keys)
            .fold<int>(0, (max, key) => key + 1 > max ? key + 1 : max);
    final colors = tracker.config.optionColors ?? const <String>[];
    final options = tracker.config.options ?? const <String>[];

    final series = List.generate(optionCount, (index) {
      return LifecycleSeries(
        label: index < options.length ? options[index] : 'Option ${index + 1}',
        values: buckets
            .map((bucket) => (bucket.choiceCounts[index] ?? 0).toDouble())
            .toList(),
        color: index < colors.length ? _parseHexColor(colors[index]) : null,
      );
    });

    return LifecycleChartData(
      granularity: granularity,
      bucketLabels: buckets.map((bucket) => bucket.label).toList(),
      series: series,
      isStacked: true,
    );
  }

  return LifecycleChartData(
    granularity: granularity,
    bucketLabels: buckets.map((bucket) => bucket.label).toList(),
    series: [
      LifecycleSeries(
        label: 'Lifecycle',
        values: buckets.map((bucket) => bucket.total).toList(),
      ),
    ],
    isStacked: false,
  );
}

List<TrackerStatCard> _buildOverviewCards({
  required Tracker tracker,
  required TrackerStatsFamily family,
  required int totalActiveDays,
  required double totalQuantity,
  required double completionRate,
  required int monthlyActiveDays,
  required double monthlyAverage,
  required List<Entry> monthlyEntries,
  required LifecycleChartData lifecycle,
  required int longestStreak,
  required int? daysSinceLastLapse,
  required ChoiceSummary? topChoice,
  required ChoiceSummary? topChoiceThisMonth,
}) {
  switch (family) {
    case TrackerStatsFamily.numeric:
      return [
        TrackerStatCard(
          label: 'Total Amount',
          value: _formatNumber(totalQuantity),
          unit: tracker.config.unit ?? 'units',
          icon: Icons.analytics,
        ),
        TrackerStatCard(
          label: 'Active Days',
          value: totalActiveDays.toString(),
          unit: 'days',
          icon: Icons.calendar_today,
        ),
        TrackerStatCard(
          label: 'Success Rate',
          value: (completionRate * 100).toStringAsFixed(0),
          unit: '%',
          icon: Icons.auto_graph,
        ),
        TrackerStatCard(
          label: 'Avg This Month',
          value: _formatNumber(monthlyAverage),
          unit: tracker.config.unit ?? 'units',
          icon: Icons.speed,
        ),
      ];
    case TrackerStatsFamily.toggle:
      final bestBucket = _bestSingleSeriesBucket(lifecycle);
      return [
        TrackerStatCard(
          label: 'Total Completions',
          value: totalActiveDays.toString(),
          unit: 'days',
          icon: Icons.check_circle_outline,
        ),
        TrackerStatCard(
          label: 'Success Rate',
          value: (completionRate * 100).toStringAsFixed(0),
          unit: '%',
          icon: Icons.auto_graph,
        ),
        TrackerStatCard(
          label: 'Times This Month',
          value: monthlyActiveDays.toString(),
          unit: 'days',
          icon: Icons.today,
        ),
        TrackerStatCard(
          label: 'Best Month',
          value: bestBucket?.label ?? 'None',
          unit: bestBucket == null
              ? ''
              : '${_formatNumber(bestBucket.total)} days',
          icon: Icons.bar_chart,
        ),
      ];
    case TrackerStatsFamily.choice:
      return [
        TrackerStatCard(
          label: 'Total Logged Days',
          value: totalActiveDays.toString(),
          unit: 'days',
          icon: Icons.event_note,
        ),
        TrackerStatCard(
          label: 'Top Choice',
          value: topChoice?.label ?? 'None',
          unit: topChoice == null ? '' : '${topChoice.count} times',
          icon: Icons.pie_chart_outline,
        ),
        TrackerStatCard(
          label: 'Top Choice This Month',
          value: topChoiceThisMonth?.label ?? 'None',
          unit: topChoiceThisMonth == null
              ? ''
              : '${topChoiceThisMonth.count} times',
          icon: Icons.calendar_view_month,
        ),
        TrackerStatCard(
          label: 'Success Rate',
          value: (completionRate * 100).toStringAsFixed(0),
          unit: '%',
          icon: Icons.auto_graph,
        ),
      ];
    case TrackerStatsFamily.abstinence:
      return [
        TrackerStatCard(
          label: 'Total Lapses',
          value: totalActiveDays.toString(),
          unit: 'days',
          icon: Icons.warning_amber_rounded,
        ),
        TrackerStatCard(
          label: 'Days Since Last Lapse',
          value: daysSinceLastLapse?.toString() ?? 'Never',
          unit: daysSinceLastLapse == null ? '' : 'days',
          icon: Icons.timelapse,
        ),
        TrackerStatCard(
          label: 'Success Rate',
          value: (completionRate * 100).toStringAsFixed(0),
          unit: '%',
          icon: Icons.auto_graph,
        ),
        TrackerStatCard(
          label: 'Longest Streak',
          value: longestStreak.toString(),
          unit: 'days',
          icon: Icons.local_fire_department,
        ),
      ];
  }
}

({String label, double total})? _bestSingleSeriesBucket(
  LifecycleChartData lifecycle,
) {
  if (lifecycle.series.isEmpty || lifecycle.bucketLabels.isEmpty) return null;
  final values = lifecycle.series.first.values;
  if (values.isEmpty) return null;

  int? bestIndex;
  double bestValue = -1;
  for (int i = 0; i < values.length; i++) {
    final value = values[i];
    if (value > bestValue ||
        (value == bestValue && bestIndex != null && i > bestIndex)) {
      bestIndex = i;
      bestValue = value;
    } else if (value > bestValue && bestIndex == null) {
      bestIndex = i;
      bestValue = value;
    }
  }

  if (bestIndex == null || bestValue <= 0) return null;
  return (label: lifecycle.bucketLabels[bestIndex], total: bestValue);
}

String _monthLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

Color? _parseHexColor(String value) {
  var hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  return Color(int.parse(hex, radix: 16));
}
