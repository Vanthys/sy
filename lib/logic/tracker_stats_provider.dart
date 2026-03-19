import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../data/providers.dart';

class TrackerStats {
  final int totalActiveDays;
  final double totalQuantity;
  final double completionRate; // Only for 'continued'
  final Map<int, int> weekdayDistribution; // 1-7 (Mon-Sun)
  final double monthlyAverage;
  final int nextMilestone;
  final int currentStreak;
  final int longestStreak;
  final DateTime? longestStreakStart;
  final DateTime? longestStreakEnd;

  TrackerStats({
    required this.totalActiveDays,
    required this.totalQuantity,
    required this.completionRate,
    required this.weekdayDistribution,
    required this.monthlyAverage,
    required this.nextMilestone,
    required this.currentStreak,
    required this.longestStreak,
    required this.longestStreakStart,
    required this.longestStreakEnd,
  });
}

final trackerStatsProvider = StreamProvider.family<TrackerStats, Tracker>((
  ref,
  tracker,
) async* {
  final entryRepo = await ref.watch(entryRepositoryProvider.future);

  yield* entryRepo.watchEntries(tracker.id).map((entries) {
    final meaningfulEntries = entries
        .where((e) => e.quantity.round() > 0)
        .toList();

    // 1. Total Active Days
    final totalActiveDays = meaningfulEntries.length;

    // 2. Total Quantity
    final totalQuantity = meaningfulEntries.fold(
      0.0,
      (sum, e) => sum + e.quantity,
    );

    // 3. Normalized Dates for calculation
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    final createdAt = tracker.createdAt;
    final createdAtMidnight = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    final sortedDays =
        meaningfulEntries
            .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
            .toList()
          ..sort();
    final earliestEntry = sortedDays.isEmpty
        ? createdAtMidnight
        : sortedDays.first;
    final trackingStartDay = earliestEntry.isBefore(createdAtMidnight)
        ? earliestEntry
        : createdAtMidnight;

    final daysSinceStart =
        todayMidnight.difference(trackingStartDay).inDays + 1;

    // 4. Completion Rate
    double completionRate = 0.0;
    if (daysSinceStart > 0) {
      if (tracker.streakType == StreakType.continued) {
        completionRate = totalActiveDays / daysSinceStart;
      } else {
        // Abstinence: success means they didn't log an incident.
        completionRate = (daysSinceStart - totalActiveDays) / daysSinceStart;
        if (completionRate < 0) completionRate = 0;
      }
    }

    // 5. Weekday Distribution (1=Mon, 7=Sun as per Dart/ISO)
    final distribution = <int, int>{};
    for (int i = 1; i <= 7; i++) {
      distribution[i] = 0;
    }

    for (final entry in meaningfulEntries) {
      distribution[entry.date.weekday] =
          (distribution[entry.date.weekday] ?? 0) + 1;
    }

    // 6. Monthly Average (last 30 days)
    final thirtyDaysAgo = DateTime(todayMidnight.year, todayMidnight.month, todayMidnight.day - 29);
    final recentEntries = meaningfulEntries.where(
      (e) => !e.date.isBefore(thirtyDaysAgo),
    );
    final monthlyAverage = recentEntries.isEmpty
        ? 0.0
        : recentEntries.fold(0.0, (sum, e) => sum + e.quantity) / 30.0;

    // 7. Next Milestone
    final milestones = [7, 14, 30, 60, 90, 100, 180, 365, 500, 1000];
    final currentStreak = tracker.currentStreak;
    final nextMilestone = milestones.firstWhere(
      (m) => m > currentStreak,
      orElse: () => ((currentStreak / 100).floor() + 1) * 100,
    );

    // 8. Longest Streak Dates
    final entryDaySet = sortedDays.toSet();
    int run = 0;
    int maxRun = 0;
    DateTime? runStart;
    DateTime? longestStart;
    DateTime? longestEnd;

    for (DateTime d = trackingStartDay;
        !d.isAfter(todayMidnight);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final hasEntry = entryDaySet.contains(d);
      final goodDay = tracker.streakType == StreakType.continued ? hasEntry : !hasEntry;
      
      if (goodDay) {
        if (run == 0) runStart = d;
        run++;
        if (run > maxRun) {
          maxRun = run;
          longestStart = runStart;
          longestEnd = d;
        }
      } else {
        run = 0;
      }
    }

    return TrackerStats(
      totalActiveDays: totalActiveDays,
      totalQuantity: totalQuantity,
      completionRate: completionRate,
      weekdayDistribution: distribution,
      monthlyAverage: monthlyAverage,
      nextMilestone: nextMilestone,
      currentStreak: tracker.currentStreak,
      longestStreak: maxRun > tracker.longestStreak ? maxRun : tracker.longestStreak,
      longestStreakStart: longestStart,
      longestStreakEnd: longestEnd,
    );
  });
});
