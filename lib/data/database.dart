//./lib/data/database.dart
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'tracker_config.dart';

part 'database.g.dart';

enum StreakType { continued, abstinence }

enum PrivacyLevel { standard, vault, secret }

@DataClassName('Tracker')
class Trackers extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  TextColumn get title => text()();
  TextColumn get description => text().nullable()();

  IntColumn get streakType => intEnum<StreakType>().named('streak_type')();
  IntColumn get privacyLevel => intEnum<PrivacyLevel>()
      .withDefault(const Constant(0))
      .named('privacy_level')();

  TextColumn get config => text().map(const TrackerConfigConverter())();

  IntColumn get currentStreak =>
      integer().withDefault(const Constant(0)).named('current_streak')();
  IntColumn get longestStreak =>
      integer().withDefault(const Constant(0)).named('longest_streak')();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('Entry')
@TableIndex(name: 'entry_index', columns: {#date})
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tracker => text().references(Trackers, #id)();

  DateTimeColumn get date => dateTime()();
  RealColumn get quantity => real()();
  TextColumn get comment => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime).named('created_at')();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime).named('updated_at')();
}

@DriftDatabase(tables: [Trackers, Entries])
class AppDatabase extends _$AppDatabase {
  static const String dbName = 'trackers.sqlite';

  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      print('Upgrading database from version $from to $to...');

      if (from < 6) {
        // Cleanup: remove old views that were using hardcoded dates
        // and potentially stale indices.
        await m.issueCustomQuery('DROP VIEW IF EXISTS recent_activity;');
        await m.issueCustomQuery('DROP VIEW IF EXISTS entry_stats;');
        await m.issueCustomQuery('DROP INDEX IF EXISTS entry_index;');

        await m.createAll();
      }

      if (from < 7) {
        await m.addColumn(
          trackers,
          trackers.privacyLevel as GeneratedColumn<Object>,
        );
      }
    },
    beforeOpen: (details) async {
      print('Database ready (version ${details.versionNow})');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name:
          'trackers', // uses dbName internally if not provided, but 'trackers' is the base name
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
