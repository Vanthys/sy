import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '/data/schemas/tracker_schema.dart';
import '/data/schemas/entry_schema.dart';

class MigrationService {
  static const _migrationDoneKey = 'isar_migration_done_v1';

  /// Runs the one-time SQLite → Isar migration if needed.
  static Future<void> runIfNeeded(Isar isar) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationDoneKey) == true) return;

    final dbPath = await _getSqlitePath();
    if (dbPath == null) {
      // No old database exists (fresh install), just mark done.
      await prefs.setBool(_migrationDoneKey, true);
      return;
    }

    await _migrate(isar, dbPath);
    await prefs.setBool(_migrationDoneKey, true);
  }

  static Future<String?> _getSqlitePath() async {
    final docsDir = await getApplicationDocumentsDirectory();
    // Drift stores it in support dir; check both common locations.
    final candidates = [
      p.join(docsDir.path, 'trackers.sqlite'),
      p.join(docsDir.path, 'trackers.db'),
    ];
    for (final path in candidates) {
      final exists = await databaseExists(path);
      if (exists) return path;
    }

    // Also check the app support directory
    try {
      final supportDir = await getApplicationSupportDirectory();
      final supportPath = p.join(supportDir.path, 'trackers.sqlite');
      if (await databaseExists(supportPath)) return supportPath;
    } catch (_) {}

    return null;
  }

  static Future<void> _migrate(Isar isar, String dbPath) async {
    final db = await openDatabase(dbPath, readOnly: true);

    try {
      final rawTrackers = await db.query('trackers', orderBy: 'created_at ASC');
      final rawEntries = await db.query('entries', orderBy: 'date ASC');

      await isar.writeTxn(() async {
        // Migrate trackers
        for (final row in rawTrackers) {
          final tracker = IsarTracker()
            ..uuid = row['id'] as String
            ..title = row['title'] as String
            ..description = row['description'] as String?
            ..streakTypeIndex = (row['streak_type'] as int? ?? 0)
            ..privacyLevelIndex = (row['privacy_level'] as int? ?? 0)
            ..configJson = (row['config'] as String?) ?? '{}'
            ..currentStreak = (row['current_streak'] as int? ?? 0)
            ..longestStreak = (row['longest_streak'] as int? ?? 0)
            ..createdAt = _parseDate(row['created_at'])
            ..updatedAt = _parseDate(row['updated_at']);
          await isar.collection<IsarTracker>().put(tracker);
        }

        // Migrate entries
        for (final row in rawEntries) {
          final entry = IsarEntry()
            ..trackerId = row['tracker'] as String
            ..date = _parseDate(row['date'])
            ..quantity = (row['quantity'] as num).toDouble()
            ..comment = row['comment'] as String?
            ..createdAt = _parseDate(row['created_at'])
            ..updatedAt = _parseDate(row['updated_at']);
          await isar.collection<IsarEntry>().put(entry);
        }
      });
    } finally {
      await db.close();
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) {
      // Drift stores datetimes as Unix milliseconds
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
    }
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }
}
