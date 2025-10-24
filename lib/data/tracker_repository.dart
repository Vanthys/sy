import 'package:drift/drift.dart';
import '/data/database.dart';
import 'tracker_config.dart';

class TrackerRepository {
  final AppDatabase db;

  TrackerRepository(this.db);

  /// Fetch all trackers, ordered by creation date (newest first)
  Future<List<Tracker>> getAllTrackers() async {
    return (db.select(db.trackers)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Stream all trackers to listen for live updates
  Stream<List<Tracker>> watchAllTrackers() {
    return (db.select(db.trackers)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Get a single tracker by ID
  Future<Tracker?> getTrackerById(String id) async {
    return (db.select(db.trackers)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create a new tracker with a given configuration
  Future<void> createTracker({
    required String title,
    String? description,
    required StreakType streakType,
    required TrackerConfig config,
  }) async {
    final now = DateTime.now();
    await db.into(db.trackers).insert(
          TrackersCompanion.insert(
            title: title,
            description: Value(description),
            streakType: streakType,
            config: config,
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Update tracker info (title, description, streaks, etc.)
  Future<void> updateTracker(
    String id, {
    String? title,
    String? description,
    StreakType? streakType,
    TrackerConfig? config,
    int? currentStreak,
    int? longestStreak,
  }) async {
    await (db.update(db.trackers)..where((t) => t.id.equals(id))).write(
      TrackersCompanion(
        title: Value.absentIfNull(title),
        description: Value.absentIfNull(description),
        streakType: Value.absentIfNull(streakType),
        config: Value.absentIfNull(config),
        currentStreak: Value.absentIfNull(currentStreak),
        longestStreak: Value.absentIfNull(longestStreak),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete tracker and optionally its entries
  Future<void> deleteTracker(String id, {bool deleteEntries = true}) async {
    if (deleteEntries) {
      await (db.delete(db.entries)..where((e) => e.tracker.equals(id))).go();
    }
    await (db.delete(db.trackers)..where((t) => t.id.equals(id))).go();
  }

  /// Update streak stats only
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
