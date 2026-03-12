import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/data/database.dart';
import '/data/schemas/tracker_schema.dart';
import '/data/schemas/entry_schema.dart';
import '/data/tracker_config.dart';

class EntryRepository {
  final Isar _isar;

  EntryRepository(this._isar);

  // shorthand collections
  IsarCollection<IsarEntry> get _entries => _isar.collection<IsarEntry>();
  IsarCollection<IsarTracker> get _trackers => _isar.collection<IsarTracker>();

  // ------------------------------------------------------------------
  // Helpers: convert [IsarEntry] ↔ app [Entry] data class
  // ------------------------------------------------------------------

  Entry _toEntry(IsarEntry e) {
    return Entry(
      id: e.id!,
      tracker: e.trackerId,
      date: e.date,
      quantity: e.quantity,
      comment: e.comment,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  Tracker _isarTrackerToTracker(IsarTracker t) {
    return Tracker(
      id: t.uuid,
      title: t.title,
      description: t.description,
      streakType: StreakType.values[t.streakTypeIndex],
      privacyLevel: PrivacyLevel.values[t.privacyLevelIndex],
      config: TrackerConfig.fromJson(jsonDecode(t.configJson)),
      currentStreak: t.currentStreak,
      longestStreak: t.longestStreak,
      createdAt: t.createdAt,
      updatedAt: t.updatedAt,
    );
  }

  // ------------------------------------------------------------------
  // Basic CRUD
  // ------------------------------------------------------------------

  Future<List<Entry>> loadEntries(String trackerId) async {
    final rows = await _entries
        .filter()
        .trackerIdEqualTo(trackerId)
        .sortByDateDesc()
        .findAll();
    return rows.map(_toEntry).toList();
  }

  Future<void> saveEntry(String trackerId, DateTime date, double amount) async {
    final normalized = DateTime(date.year, date.month, date.day);

    final existing = await _entries
        .filter()
        .trackerIdEqualTo(trackerId)
        .and()
        .dateEqualTo(normalized)
        .findFirst();

    await _isar.writeTxn(() async {
      if (amount > 0) {
        if (existing != null) {
          existing.quantity = amount;
          existing.updatedAt = DateTime.now();
          await _entries.put(existing);
        } else {
          final entry = IsarEntry()
            ..trackerId = trackerId
            ..date = normalized
            ..quantity = amount
            ..createdAt = DateTime.now()
            ..updatedAt = DateTime.now();
          await _entries.put(entry);
        }
      } else if (existing != null) {
        await _entries.delete(existing.id!);
      }
    });

    await updateTrackerStreaks(trackerId);
  }

  Stream<List<Entry>> watchEntries(String trackerId) {
    return _entries
        .filter()
        .trackerIdEqualTo(trackerId)
        .sortByDateDesc()
        .watch(fireImmediately: true)
        .map((list) => list.map(_toEntry).toList());
  }

  Future<void> deleteEntry(int id) async {
    final row = await _entries.get(id);
    if (row == null) return;

    await _isar.writeTxn(() => _entries.delete(id));
    await updateTrackerStreaks(row.trackerId);
  }

  Stream<List<Entry>> watchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) {
    final toInclusive = DateTime(to.year, to.month, to.day + 1);
    return _entries
        .filter()
        .trackerIdEqualTo(trackerId)
        .and()
        .dateBetween(from, toInclusive)
        .sortByDateDesc()
        .watch(fireImmediately: true)
        .map((list) => list.map(_toEntry).toList());
  }

  Future<List<Entry>> fetchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) async {
    final toInclusive = DateTime(to.year, to.month, to.day + 1);
    final rows = await _entries
        .filter()
        .trackerIdEqualTo(trackerId)
        .and()
        .dateBetween(from, toInclusive)
        .sortByDateDesc()
        .findAll();
    return rows.map(_toEntry).toList();
  }

  // ------------------------------------------------------------------
  // Streak Recalculation
  // ------------------------------------------------------------------

  Future<void> updateTrackerStreaks(String trackerId) async {
    final trackerRow = await _trackers
        .filter()
        .uuidEqualTo(trackerId)
        .findFirst();
    if (trackerRow == null) return;

    final tracker = _isarTrackerToTracker(trackerRow);
    final entries = await loadEntries(trackerId);
    final (current, longest) = _computeStreaks(tracker, entries);

    trackerRow.currentStreak = current;
    trackerRow.longestStreak = longest;
    trackerRow.updatedAt = DateTime.now();
    await _isar.writeTxn(() => _trackers.put(trackerRow));
  }

  Future<void> refreshAllStreaks({bool force = false}) async {
    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final lastRefresh = prefs.getString('last_streak_refresh_date');
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      if (lastRefresh == todayStr) return;
    }

    final trackerRows = await _trackers.where().findAll();
    final allEntryRows = await _entries.where().findAll();

    final entryGroups = <String, List<Entry>>{};
    for (final e in allEntryRows) {
      entryGroups.putIfAbsent(e.trackerId, () => []).add(_toEntry(e));
    }

    final trackers = trackerRows.map(_isarTrackerToTracker).toList();

    final updates = await compute(
      _recalculateStreaksTask,
      _StreakBatchPayload(trackers: trackers, entryGroups: entryGroups),
    );

    await _isar.writeTxn(() async {
      for (final update in updates) {
        final row = await _trackers.filter().uuidEqualTo(update.id).findFirst();
        if (row == null) continue;
        row.currentStreak = update.current;
        row.longestStreak = update.longest;
        row.updatedAt = DateTime.now();
        await _trackers.put(row);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().split('T').first;
    await prefs.setString('last_streak_refresh_date', todayStr);
  }
}

// ------------------------------------------------------------------
// Isolate helpers — streak logic unchanged from the Drift version
// ------------------------------------------------------------------

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

  // Current streak (ending today), DST-safe
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
