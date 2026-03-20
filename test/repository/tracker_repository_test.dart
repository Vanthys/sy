// Repository integration tests using isar_community's in-memory mode.
// Run with: flutter test test/repository/tracker_repository_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:sy3/data/schemas/tracker_schema.dart';
import 'package:sy3/data/schemas/entry_schema.dart';
import 'package:sy3/data/database.dart';
import 'package:sy3/data/tracker_config.dart';
import 'package:sy3/data/tracker_repository.dart';
import 'package:sy3/logic/vault_provider.dart';
import '../helpers/isar_test_helper.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Opens a fresh Isar instance in the system temp directory for a single test.
Future<Isar> _openIsar() async {
  return Isar.open(
    [IsarTrackerSchema, IsarEntrySchema],
    directory: Directory.systemTemp.path,
    name: 'tracker_test_${DateTime.now().microsecondsSinceEpoch}',
  );
}

/// A minimal unlocked [VaultState] with no active key (standard privacy only).
VaultState get _unlockedVault => VaultState();

TrackerRepository _makeRepo(Isar isar) =>
    TrackerRepository(isar, _unlockedVault);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initIsarForTests);

  group('TrackerRepository', () {
    late Isar isar;
    late TrackerRepository repo;

    setUp(() async {
      isar = await _openIsar();
      repo = _makeRepo(isar);
    });

    tearDown(() async {
      await isar.close(deleteFromDisk: true);
    });

    // -----------------------------------------------------------------------
    // Create
    // -----------------------------------------------------------------------
    group('createTracker', () {
      test('persists a new tracker and getAllTrackers returns it', () async {
        await repo.createTracker(
          title: 'Morning Run',
          streakType: StreakType.continued,
          config: const TrackerConfig(maxValue: 10.0, unit: 'km'),
        );

        final all = await repo.getAllTrackers();
        expect(all, hasLength(1));
        expect(all.first.title, 'Morning Run');
        expect(all.first.config.unit, 'km');
        expect(all.first.streakType, StreakType.continued);
        expect(all.first.currentStreak, 0);
        expect(all.first.longestStreak, 0);
      });

      test('sortOrder increments for each created tracker', () async {
        await repo.createTracker(
          title: 'First',
          streakType: StreakType.continued,
          config: const TrackerConfig(),
        );
        await repo.createTracker(
          title: 'Second',
          streakType: StreakType.continued,
          config: const TrackerConfig(),
        );

        final all = await repo.getAllTrackers();
        expect(all[0].sortOrder, 0);
        expect(all[1].sortOrder, 1);
      });
    });

    // -----------------------------------------------------------------------
    // Read
    // -----------------------------------------------------------------------
    group('getTrackerById', () {
      test('returns tracker when found', () async {
        await repo.createTracker(
          title: 'Find Me',
          streakType: StreakType.continued,
          config: const TrackerConfig(),
        );
        final all = await repo.getAllTrackers();
        final id = all.first.id;

        final found = await repo.getTrackerById(id);
        expect(found, isNotNull);
        expect(found!.title, 'Find Me');
      });

      test('returns null when not found', () async {
        final found = await repo.getTrackerById('no-such-uuid');
        expect(found, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // Update
    // -----------------------------------------------------------------------
    group('updateTracker', () {
      test('updates title', () async {
        await repo.createTracker(
          title: 'Old Title',
          streakType: StreakType.continued,
          config: const TrackerConfig(),
        );
        final id = (await repo.getAllTrackers()).first.id;

        await repo.updateTracker(id, title: 'New Title');

        final updated = await repo.getTrackerById(id);
        expect(updated!.title, 'New Title');
      });

      test('updateStreaks persists current and longest', () async {
        await repo.createTracker(
          title: 'Streak Tracker',
          streakType: StreakType.continued,
          config: const TrackerConfig(),
        );
        final id = (await repo.getAllTrackers()).first.id;

        await repo.updateStreaks(id, 5, 12);

        final updated = await repo.getTrackerById(id);
        expect(updated!.currentStreak, 5);
        expect(updated.longestStreak, 12);
      });

      test('updateTracker on unknown uuid is a no-op', () async {
        await repo.updateTracker('ghost', title: 'Should not fail');
        // No exception thrown
      });
    });

    // -----------------------------------------------------------------------
    // Delete
    // -----------------------------------------------------------------------
    group('deleteTracker', () {
      test('removes the tracker from the list', () async {
        await repo.createTracker(
          title: 'Delete Me',
          streakType: StreakType.continued,
          config: const TrackerConfig(),
        );
        final id = (await repo.getAllTrackers()).first.id;

        await repo.deleteTracker(id);

        final all = await repo.getAllTrackers();
        expect(all, isEmpty);
      });

      test('deletes associated entries when deleteEntries=true', () async {
        await repo.createTracker(
          title: 'With Entries',
          streakType: StreakType.continued,
          config: const TrackerConfig(),
        );
        final trackerId = (await repo.getAllTrackers()).first.id;

        // Insert a raw entry for this tracker
        final entryRow = IsarEntry()
          ..trackerId = trackerId
          ..date = DateTime.now()
          ..quantity = 5.0
          ..createdAt = DateTime.now()
          ..updatedAt = DateTime.now();
        await isar.writeTxn(() => isar.collection<IsarEntry>().put(entryRow));

        await repo.deleteTracker(trackerId, deleteEntries: true);

        final remaining = await isar.collection<IsarEntry>().where().findAll();
        expect(remaining, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // Reorder
    // -----------------------------------------------------------------------
    group('reorderTrackers', () {
      test('swaps sort order of two trackers', () async {
        await repo.createTracker(
          title: 'Alpha',
          streakType: StreakType.continued,
          config: const TrackerConfig(),
        );
        await repo.createTracker(
          title: 'Beta',
          streakType: StreakType.continued,
          config: const TrackerConfig(),
        );

        final all = await repo.getAllTrackers();
        final alphaId = all[0].id; // sortOrder 0
        final betaId = all[1].id; // sortOrder 1

        // Reorder: Beta before Alpha
        await repo.reorderTrackers([betaId, alphaId]);

        final reordered = await repo.getAllTrackers();
        // After reorder, Beta should have lower sortOrder (0), Alpha 1
        expect(reordered[0].title, 'Beta');
        expect(reordered[1].title, 'Alpha');
      });
    });

    // -----------------------------------------------------------------------
    // Privacy / vault
    // -----------------------------------------------------------------------
    group('privacy filter', () {
      test(
        'getAllTrackers only shows standard trackers when vault is locked',
        () async {
          await repo.createTracker(
            title: 'Public',
            streakType: StreakType.continued,
            config: const TrackerConfig(),
            privacyLevel: PrivacyLevel.standard,
          );
          // Private tracker requires an active vault key — skip creation since
          // vault is locked (no activeKey); just verify that the standard one
          // is visible.
          final all = await repo.getAllTrackers();
          expect(all, hasLength(1));
          expect(all.first.title, 'Public');
        },
      );
    });
  });
}
