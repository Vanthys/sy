// streak_logic.dart
// Public, pure-Dart streak computation extracted from entry_repository.dart
// so it can be unit-tested without an Isar instance.

import '/data/database.dart';

/// Computes `(currentStreak, longestStreak)` for [tracker] given its [entries].
///
/// * **Continued** tracker: a streak day is one that HAS an entry with quantity > 0.
/// * **Abstinence** tracker: a streak day is one that does NOT have an entry.
(int current, int longest) computeStreaks(
  Tracker tracker,
  List<Entry> entries,
) {
  final type = tracker.streakType;
  final createdAt = tracker.createdAt;
  final createdAtMidnight = DateTime(
    createdAt.year,
    createdAt.month,
    createdAt.day,
  );

  final today = DateTime.now();
  final todayMidnight = DateTime(today.year, today.month, today.day);

  final entryDays = entries
      .where((e) => e.quantity.round() > 0)
      .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
      .toSet();

  final sortedDays = entryDays.toList()..sort();
  final earliestEntry = sortedDays.isEmpty
      ? createdAtMidnight
      : sortedDays.first;
  final trackingStartDay = earliestEntry.isBefore(createdAtMidnight)
      ? earliestEntry
      : createdAtMidnight;

  if (entries.isEmpty) {
    final daysSinceStart =
        todayMidnight.difference(trackingStartDay).inDays + 1;
    return type == StreakType.continued
        ? (0, 0)
        : (daysSinceStart, daysSinceStart);
  }

  // Longest streak
  int longest = 0;
  int streak = 0;
  for (
    DateTime d = trackingStartDay;
    !d.isAfter(todayMidnight);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    final hasEntry = entryDays.contains(d);
    final goodDay = type == StreakType.continued ? hasEntry : !hasEntry;
    if (goodDay) {
      streak++;
      if (streak > longest) longest = streak;
    } else {
      streak = 0;
    }
  }

  // Current streak (ending today or yesterday for continued), DST-safe
  int current = 0;
  DateTime curDay = todayMidnight;

  if (type == StreakType.continued && !entryDays.contains(curDay)) {
    curDay = DateTime(curDay.year, curDay.month, curDay.day - 1);
  }

  while (!curDay.isBefore(trackingStartDay)) {
    final hasEntry = entryDays.contains(curDay);
    final goodDay = type == StreakType.continued ? hasEntry : !hasEntry;
    if (!goodDay) break;
    current++;
    curDay = DateTime(curDay.year, curDay.month, curDay.day - 1);
  }

  return (current, longest);
}
