//./lib/data/database.dart
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

enum StreakType {
  continued,
  abstinence,
}


@DataClassName('Tracker')
class Trackers extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();

  TextColumn get title => text().withLength(min: 1, max: 50)();
  TextColumn get description => text().nullable()();

  IntColumn get streakType => intEnum<StreakType>().named('streak_type')();

  TextColumn get unitName => text().nullable().named('unit_name')();
  TextColumn get unitAbbreviation => text().nullable().named('unit_abbreviation')();

  IntColumn get currentStreak =>
      integer().withDefault(const Constant(0)).named('current_streak')();
  IntColumn get longestStreak =>
      integer().withDefault(const Constant(0)).named('longest_streak')();

  DateTimeColumn get createdAt => dateTime()
      .withDefault(currentDateAndTime)
      .named('created_at')();
  DateTimeColumn get updatedAt => dateTime()
      .withDefault(currentDateAndTime)
      .named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => {id};
}


@DataClassName('Entry')
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
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'trackers',
      native: const DriftNativeOptions(
        // By default, `driftDatabase` from `package:drift_flutter` stores the
        // database files in `getApplicationDocumentsDirectory()`.
        databaseDirectory: getApplicationSupportDirectory,
      ),
      // If you need web support, see https://drift.simonbinder.eu/platforms/web/
    );
  }
}

