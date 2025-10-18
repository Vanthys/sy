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
    final existing = await (db.select(db.entries)
          ..where((e) => e.tracker.equals(trackerId))
          ..where((e) => e.date.equals(normalized)))
        .getSingleOrNull();

    if (amount > 0) {
      if (existing != null) {
        await (db.update(db.entries)..where((e) => e.id.equals(existing.id))).write(
          EntriesCompanion(
            quantity: Value(amount),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await db.into(db.entries).insert(
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
      await (db.delete(db.entries)..where((e) => e.id.equals(existing.id))).go();
    }

    // 🟢 NEW: Update streak stats after any change
    await _updateTrackerStreaks(trackerId);
  }

  Stream<List<Entry>> watchEntries(String trackerId) {
    return (db.select(db.entries)
          ..where((e) => e.tracker.equals(trackerId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .watch();
  }

  Future<void> deleteEntry(int id) async {
    // 🟡 Get trackerId before deleting
    final entry =
        await (db.select(db.entries)..where((e) => e.id.equals(id))).getSingleOrNull();
    if (entry == null) return;

    await (db.delete(db.entries)..where((e) => e.id.equals(id))).go();

    // 🟢 Update streaks after deletion
    await _updateTrackerStreaks(entry.tracker);
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
  Future<void> _updateTrackerStreaks(String trackerId) async {
    final tracker = await (db.select(db.trackers)
          ..where((t) => t.id.equals(trackerId)))
        .getSingleOrNull();
    if (tracker == null) return;

    final entries = await loadEntries(trackerId);
    final (current, longest) = _computeStreaks(tracker.streakType, entries);

    await (db.update(db.trackers)..where((t) => t.id.equals(trackerId))).write(
      TrackersCompanion(
        currentStreak: Value(current),
        longestStreak: Value(longest),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

    (int current, int longest) _computeStreaks(
      StreakType type, List<Entry> entries) {
    if (entries.isEmpty) {
      // continued → no entries → no streak
      // abstinence → no entries → full streak from start of tracking
      final today = DateTime.now();
      final start = today; // you can later persist tracker.createdAt if desired
      final daysSinceStart = today.difference(start).inDays + 1;
      return type == StreakType.continued ? (0, 0) : (daysSinceStart, daysSinceStart);
    }

    // Sort ascending by date
    final sorted = entries.map((e) => e.date).toList()..sort();
    final today = DateTime.now();

    // Normalize all entry dates (midnight)
    final entryDays = sorted.map((d) => DateTime(d.year, d.month, d.day)).toSet();

    // --------------------------------------------------------
    // Compute Longest Streak
    // --------------------------------------------------------
    int longest = 0;
    int streak = 0;

    // We iterate day-by-day for clarity and correctness
    for (DateTime d = entryDays.first;
        !d.isAfter(today);
        d = d.add(const Duration(days: 1))) {
      final hasEntry = entryDays.contains(d);
      final goodDay =
          type == StreakType.continued ? hasEntry : !hasEntry;

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
    DateTime curDay = DateTime(today.year, today.month, today.day);

    while (true) {
      final hasEntry = entryDays.contains(curDay);
      final goodDay =
          type == StreakType.continued ? hasEntry : !hasEntry;

      if (!goodDay) break;
      current++;
      curDay = curDay.subtract(const Duration(days: 1));
    }

    return (current, longest);
  }

}
