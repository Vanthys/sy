// Entry repository integration tests using isar_community's in-memory mode.
// Run with: flutter test test/repository/entry_repository_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:sy3/data/schemas/tracker_schema.dart';
import 'package:sy3/data/schemas/entry_schema.dart';
import 'package:sy3/data/database.dart';
import 'package:sy3/data/tracker_config.dart';
import 'package:sy3/data/entry_repository.dart';
import '../helpers/isar_test_helper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<Isar> _openIsar() async {
  return Isar.open(
    [IsarTrackerSchema, IsarEntrySchema],
    directory: Directory.systemTemp.path,
    name: 'entry_test_${DateTime.now().microsecondsSinceEpoch}',
  );
}

/// Creates a minimal [IsarTracker] row and returns its UUID.
Future<String> _createRawTracker(
  Isar isar, {
  StreakType streakType = StreakType.continued,
}) async {
  final uuid = 'tracker-uuid-${DateTime.now().microsecondsSinceEpoch}';
  final row = IsarTracker()
    ..uuid = uuid
    ..title = 'Test'
    ..streakTypeIndex = streakType.index
    ..privacyLevelIndex = PrivacyLevel.standard.index
    ..configJson = jsonEncode(const TrackerConfig().toJson())
    ..currentStreak = 0
    ..longestStreak = 0
    ..createdAt = DateTime(2025)
    ..updatedAt = DateTime(2025)
    ..sortOrder = 0;
  await isar.writeTxn(() => isar.collection<IsarTracker>().put(row));
  return uuid;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initIsarForTests);

  group('EntryRepository', () {
    late Isar isar;
    late EntryRepository repo;
    late String trackerId;

    setUp(() async {
      isar = await _openIsar();
      repo = EntryRepository(isar);
      trackerId = await _createRawTracker(isar);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
    });

    // -----------------------------------------------------------------------
    // saveEntry / loadEntries
    // -----------------------------------------------------------------------
    group('saveEntry', () {
      test('creates a new entry when amount > 0', () async {
        final date = DateTime(2025, 3, 10);
        await repo.saveEntry(trackerId, date, 5.0);

        final entries = await repo.loadEntries(trackerId);
        expect(entries, hasLength(1));
        expect(entries.first.quantity, 5.0);
        expect(entries.first.date, DateTime(2025, 3, 10));
      });

      test('upserts existing entry on the same date', () async {
        final date = DateTime(2025, 3, 10);
        await repo.saveEntry(trackerId, date, 3.0);
        await repo.saveEntry(trackerId, date, 7.0);

        final entries = await repo.loadEntries(trackerId);
        expect(entries, hasLength(1));
        expect(entries.first.quantity, 7.0);
      });

      test('deletes entry when amount == 0 and entry exists', () async {
        final date = DateTime(2025, 3, 10);
        await repo.saveEntry(trackerId, date, 4.0);
        await repo.saveEntry(trackerId, date, 0.0);

        final entries = await repo.loadEntries(trackerId);
        expect(entries, isEmpty);
      });

      test('no-op when amount == 0 and no entry exists', () async {
        final date = DateTime(2025, 3, 11);
        await repo.saveEntry(trackerId, date, 0.0); // should not throw

        final entries = await repo.loadEntries(trackerId);
        expect(entries, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // loadEntries sort order
    // -----------------------------------------------------------------------
    group('loadEntries', () {
      test('returns entries sorted newest first', () async {
        await repo.saveEntry(trackerId, DateTime(2025, 3, 1), 1.0);
        await repo.saveEntry(trackerId, DateTime(2025, 3, 5), 2.0);
        await repo.saveEntry(trackerId, DateTime(2025, 3, 3), 3.0);

        final entries = await repo.loadEntries(trackerId);
        expect(entries.map((e) => e.date.day).toList(), [5, 3, 1]);
      });
    });

    // -----------------------------------------------------------------------
    // deleteEntry
    // -----------------------------------------------------------------------
    group('deleteEntry', () {
      test('removes the entry by id', () async {
        final date = DateTime(2025, 4, 1);
        await repo.saveEntry(trackerId, date, 2.0);

        final before = await repo.loadEntries(trackerId);
        expect(before, hasLength(1));

        await repo.deleteEntry(before.first.id);

        final after = await repo.loadEntries(trackerId);
        expect(after, isEmpty);
      });

      test('no-op when id does not exist', () async {
        await repo.deleteEntry(-999); // should not throw
      });
    });

    // -----------------------------------------------------------------------
    // fetchEntriesInRange
    // -----------------------------------------------------------------------
    group('fetchEntriesInRange', () {
      test('only returns entries within the date range', () async {
        await repo.saveEntry(trackerId, DateTime(2025, 3, 1), 1.0);
        await repo.saveEntry(trackerId, DateTime(2025, 3, 15), 2.0);
        await repo.saveEntry(trackerId, DateTime(2025, 3, 31), 3.0);

        final entries = await repo.fetchEntriesInRange(
          trackerId,
          DateTime(2025, 3, 10),
          DateTime(2025, 3, 20),
        );
        expect(entries, hasLength(1));
        expect(entries.first.date.day, 15);
      });
    });

    // -----------------------------------------------------------------------
    // Streak recalculation (continued tracker)
    // -----------------------------------------------------------------------
    group('streak recalculation', () {
      test('consecutive entries produce increasing streaks', () async {
        final yesterday = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day - 1,
        );
        final today = DateTime.now();

        await repo.saveEntry(trackerId, yesterday, 1.0);
        await repo.saveEntry(trackerId, today, 1.0);

        // After saveEntry, streaks are recalculated by the repository.
        final row = await isar
            .collection<IsarTracker>()
            .filter()
            .uuidEqualTo(trackerId)
            .findFirst();

        expect(row!.currentStreak, greaterThanOrEqualTo(1));
        expect(row.longestStreak, greaterThanOrEqualTo(2));
      });

      test('deleting entry re-computes streaks downward', () async {
        final today = DateTime.now();
        await repo.saveEntry(trackerId, today, 1.0);

        final entries = await repo.loadEntries(trackerId);
        await repo.deleteEntry(entries.first.id);

        final row = await isar
            .collection<IsarTracker>()
            .filter()
            .uuidEqualTo(trackerId)
            .findFirst();
        expect(row!.currentStreak, 0);
      });
    });
  });
}
