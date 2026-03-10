import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';
import '/data/database.dart';

class EntryRepository {
  final AppDatabase db;

  EntryRepository(this.db);

  Future<List<Entry>> loadEntries(String trackerId) async {
    return (db.select(db.entries)
          ..where((e) => e.tracker.equals(trackerId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .get();
  }

  Future<void> saveEntry(String trackerId, DateTime date, double amount) async {
    // Normalize: strip time part
    final normalized = DateTime(date.year, date.month, date.day);

    // Try to find existing record for that date
    final existing =
        await (db.select(db.entries)
              ..where((e) => e.tracker.equals(trackerId))
              ..where((e) => e.date.equals(normalized)))
            .getSingleOrNull();

    if (amount > 0) {
      if (existing != null) {
        await (db.update(
          db.entries,
        )..where((e) => e.id.equals(existing.id))).write(
          EntriesCompanion(
            quantity: Value(amount),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await db
            .into(db.entries)
            .insert(
              EntriesCompanion(
                tracker: Value(trackerId),
                date: Value(normalized),
                quantity: Value(amount),
                createdAt: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    } else if (existing != null) {
      await (db.delete(
        db.entries,
      )..where((e) => e.id.equals(existing.id))).go();
    }

    // 🟢 NEW: Update streak stats after any change
    await updateTrackerStreaks(trackerId);
  }

  Stream<List<Entry>> watchEntries(String trackerId) {
    return (db.select(db.entries)
          ..where((e) => e.tracker.equals(trackerId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch();
  }

  Future<void> deleteEntry(int id) async {
    // 🟡 Get trackerId before deleting
    final entry = await (db.select(
      db.entries,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    if (entry == null) return;

    await (db.delete(db.entries)..where((e) => e.id.equals(id))).go();

    // 🟢 Update streaks after deletion
    await updateTrackerStreaks(entry.tracker);
  }

  Stream<List<Entry>> watchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) {
    final toInclusive = to.add(const Duration(days: 1));

    final query = (db.select(db.entries)
      ..where((e) => e.tracker.equals(trackerId))
      ..where((e) => e.date.isBetweenValues(from, toInclusive))
      ..orderBy([(e) => OrderingTerm.desc(e.date)]));
    return query.watch();
  }

  Future<List<Entry>> fetchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) async {
    final toInclusive = to.add(const Duration(days: 1));
    return (db.select(db.entries)
          ..where((e) => e.tracker.equals(trackerId))
          ..where((e) => e.date.isBetweenValues(from, toInclusive))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .get();
  }

  // ------------------------------------------------------------
  // 🔥 NEW — Streak Recalculation & Tracker Update
  // ------------------------------------------------------------
  // ------------------------------------------------------------
  // 🔥 NEW — Streak Recalculation & Tracker Update
  // ------------------------------------------------------------
  Future<void> refreshAllStreaks({bool force = false}) async {
    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final lastRefresh = prefs.getString('last_streak_refresh_date');
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      if (lastRefresh == todayStr) {
        // Already refreshed today, skip unless forced
        return;
      }
    }

    final trackers = await db.select(db.trackers).get();

    // Fetch all entries for all trackers in one go to minimize DB calls
    final allEntries = await db.select(db.entries).get();

    // Group entries by trackerId for the isolate
    final entryGroups = <String, List<Entry>>{};
    for (final e in allEntries) {
      entryGroups.putIfAbsent(e.tracker, () => []).add(e);
    }

    // Run heavy calculations in background isolate
    final updates = await compute(
      _recalculateStreaksTask,
      _StreakBatchPayload(trackers: trackers, entryGroups: entryGroups),
    );

    // Batch update the DB with results
    await db.batch((batch) {
      for (final update in updates) {
        batch.update(
          db.trackers,
          TrackersCompanion(
            currentStreak: Value(update.current),
            longestStreak: Value(update.longest),
            updatedAt: Value(DateTime.now()),
          ),
          where: (t) => t.id.equals(update.id),
        );
      }
    });

    // Save the refresh date
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    await prefs.setString('last_streak_refresh_date', todayStr);
  }

  // ------------------------------------------------------------
  // 🔥 Streak Recalculation & Tracker Update
  // ------------------------------------------------------------
  Future<void> updateTrackerStreaks(String trackerId) async {
    final tracker = await (db.select(
      db.trackers,
    )..where((t) => t.id.equals(trackerId))).getSingleOrNull();
    if (tracker == null) return;

    final entries = await loadEntries(trackerId);
    final (current, longest) = _computeStreaks(tracker, entries);

    await (db.update(db.trackers)..where((t) => t.id.equals(trackerId))).write(
      TrackersCompanion(
        currentStreak: Value(current),
        longestStreak: Value(longest),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

// ------------------------------------------------------------
// 🏗️ Isolate Helpers for Streak Recalculation
// ------------------------------------------------------------

class _StreakBatchPayload {
  final List<Tracker> trackers;
  final Map<String, List<Entry>> entryGroups;

  _StreakBatchPayload({required this.trackers, required this.entryGroups});
}

class _StreakUpdate {
  final String id;
  final int current;
  final int longest;

  _StreakUpdate({
    required this.id,
    required this.current,
    required this.longest,
  });
}

/// Top-level function for background isolate execution
List<_StreakUpdate> _recalculateStreaksTask(_StreakBatchPayload payload) {
  final results = <_StreakUpdate>[];

  for (final t in payload.trackers) {
    final entries = payload.entryGroups[t.id] ?? [];
    final (current, longest) = _computeStreaks(t, entries);
    results.add(_StreakUpdate(id: t.id, current: current, longest: longest));
  }

  return results;
}

(int current, int longest) _computeStreaks(
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

  // --------------------------------------------------------
  // Determine Tracking Origin
  // --------------------------------------------------------
  // We look for the earliest entry ever logged to allow historical back-logging
  final sortedDays = entryDays.toList()..sort();
  final earliestEntry = sortedDays.isEmpty
      ? createdAtMidnight
      : sortedDays.first;

  // The official "Tracking Start" is whichever came first: creation or first entry
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

  // --------------------------------------------------------
  // Compute Longest Streak
  // --------------------------------------------------------
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

  // --------------------------------------------------------
  // Compute Current Streak (ending today)
  // --------------------------------------------------------
  int current = 0;
  DateTime curDay = todayMidnight;

  // For continued: if today has no entry, check yesterday to keep streak alive
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
