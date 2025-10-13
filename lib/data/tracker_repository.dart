import 'package:drift/drift.dart';
import '/data/database.dart';

class TrackerRepository {
  final AppDatabase db;

  TrackerRepository(this.db);

  Future<List<Tracker>> getAllTrackers() async {
    return (db.select(db.trackers)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Stream<List<Tracker>> watchAllTrackers() {
    return (db.select(db.trackers)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<Tracker?> getTrackerById(String id) async {
    return (db.select(db.trackers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> createTracker({
    required String title,
    String? description,
    required StreakType streakType,
    String? unitName,
    String? unitAbbreviation,
  }) async {
    final now = DateTime.now();
    await db.into(db.trackers).insert(
          TrackersCompanion.insert(
            title: title,
            description: Value(description),
            streakType: streakType,
            unitName: Value(unitName),
            unitAbbreviation: Value(unitAbbreviation),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> updateTracker(
    String id, {
    String? title,
    String? description,
    StreakType? streakType,
    String? unitName,
    String? unitAbbreviation,
    int? currentStreak,
    int? longestStreak,
  }) async {
    await (db.update(db.trackers)..where((t) => t.id.equals(id))).write(
      TrackersCompanion(
        title: Value.absentIfNull(title),
        description: Value.absentIfNull(description),
        streakType: Value.absentIfNull(streakType),
        unitName: Value.absentIfNull(unitName),
        unitAbbreviation: Value.absentIfNull(unitAbbreviation),
        currentStreak: Value.absentIfNull(currentStreak),
        longestStreak: Value.absentIfNull(longestStreak),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteTracker(String id, {bool deleteEntries = true}) async {
    if (deleteEntries) {
      await (db.delete(db.entries)..where((e) => e.tracker.equals(id))).go();
    }
    await (db.delete(db.trackers)..where((t) => t.id.equals(id))).go();
  }

  Future<void> updateStreaks(String id, int current, int longest) async {
    await (db.update(db.trackers)..where((t) => t.id.equals(id))).write(
      TrackersCompanion(
        currentStreak: Value(current),
        longestStreak: Value(longest),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
