import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy3/data/database.dart';
import 'package:sy3/data/entry_repository.dart';
import 'package:sy3/data/providers.dart';
import 'package:sy3/data/tracker_config.dart';
import 'package:sy3/logic/tracker_stats_provider.dart';

class _StatsEntryRepository implements EntryRepository {
  _StatsEntryRepository(this.entries);

  final List<Entry> entries;
  String? requestedTrackerId;

  @override
  Stream<List<Entry>> watchEntries(String trackerId) {
    requestedTrackerId = trackerId;
    return Stream.value(entries);
  }

  @override
  Future<void> deleteEntry(int id) => throw UnimplementedError();

  @override
  Future<List<Entry>> fetchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) => throw UnimplementedError();

  @override
  Future<List<Entry>> loadEntries(String trackerId) => throw UnimplementedError();

  @override
  Future<void> refreshAllStreaks({bool force = false}) =>
      throw UnimplementedError();

  @override
  Future<void> saveEntry(String trackerId, DateTime date, double amount) =>
      throw UnimplementedError();

  @override
  Future<void> updateTrackerStreaks(String trackerId) =>
      throw UnimplementedError();

  @override
  Stream<List<Entry>> watchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) => throw UnimplementedError();
}

DateTime _dayFrom(DateTime anchor, int offset) {
  return DateTime(anchor.year, anchor.month, anchor.day + offset);
}

Entry _entry({
  required int id,
  required String trackerId,
  required DateTime date,
  required double quantity,
}) {
  return Entry(
    id: id,
    tracker: trackerId,
    date: date,
    quantity: quantity,
    createdAt: date,
    updatedAt: date,
  );
}

Tracker _tracker({
  required String id,
  required DateTime createdAt,
  required StreakType streakType,
  int currentStreak = 0,
  int longestStreak = 0,
}) {
  return Tracker(
    id: id,
    title: 'Tracker',
    streakType: streakType,
    config: const TrackerConfig(),
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Map<int, int> _weekdayCounts(List<DateTime> dates) {
  final counts = {for (int weekday = 1; weekday <= 7; weekday++) weekday: 0};
  for (final date in dates) {
    counts[date.weekday] = counts[date.weekday]! + 1;
  }
  return counts;
}

ProviderContainer _buildContainer(_StatsEntryRepository repository) {
  return ProviderContainer(
    overrides: [
      entryRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
}

ProviderSubscription<AsyncValue<TrackerStats>> _keepStatsAlive(
  ProviderContainer container,
  Tracker tracker,
) {
  return container.listen<AsyncValue<TrackerStats>>(
    trackerStatsProvider(tracker),
    (previous, next) {},
  );
}

void main() {
  group('trackerStatsProvider', () {
    test('calculates continued-tracker aggregates and longest streak dates', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tracker = _tracker(
        id: 'continued',
        createdAt: _dayFrom(today, -5),
        streakType: StreakType.continued,
        currentStreak: 8,
        longestStreak: 1,
      );
      final dates = [
        _dayFrom(today, -5),
        _dayFrom(today, -4),
        _dayFrom(today, -2),
        today,
      ];
      final repository = _StatsEntryRepository([
        _entry(
          id: 1,
          trackerId: tracker.id,
          date: dates[0],
          quantity: 1,
        ),
        _entry(
          id: 2,
          trackerId: tracker.id,
          date: dates[1],
          quantity: 2,
        ),
        _entry(
          id: 3,
          trackerId: tracker.id,
          date: dates[2],
          quantity: 3,
        ),
        _entry(
          id: 4,
          trackerId: tracker.id,
          date: dates[3],
          quantity: 4,
        ),
        _entry(
          id: 5,
          trackerId: tracker.id,
          date: _dayFrom(today, -1),
          quantity: 0,
        ),
      ]);
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      final sub = _keepStatsAlive(container, tracker);
      addTearDown(sub.close);

      final stats = await container.read(trackerStatsProvider(tracker).future);

      expect(repository.requestedTrackerId, tracker.id);
      expect(stats.totalActiveDays, 4);
      expect(stats.totalQuantity, 10);
      expect(stats.completionRate, closeTo(4 / 6, 0.000001));
      expect(stats.weekdayDistribution, _weekdayCounts(dates));
      expect(stats.monthlyAverage, closeTo(10 / 30, 0.000001));
      expect(stats.nextMilestone, 14);
      expect(stats.currentStreak, 8);
      expect(stats.longestStreak, 2);
      expect(stats.longestStreakStart, dates[0]);
      expect(stats.longestStreakEnd, dates[1]);
    });

    test('calculates abstinence stats and milestone fallback above 1000', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tracker = _tracker(
        id: 'abstinence',
        createdAt: _dayFrom(today, -4),
        streakType: StreakType.abstinence,
        currentStreak: 1001,
        longestStreak: 1,
      );
      final dates = [_dayFrom(today, -3), today];
      final repository = _StatsEntryRepository([
        _entry(
          id: 1,
          trackerId: tracker.id,
          date: dates[0],
          quantity: 2.5,
        ),
        _entry(
          id: 2,
          trackerId: tracker.id,
          date: dates[1],
          quantity: 1,
        ),
      ]);
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      final sub = _keepStatsAlive(container, tracker);
      addTearDown(sub.close);

      final stats = await container.read(trackerStatsProvider(tracker).future);

      expect(stats.totalActiveDays, 2);
      expect(stats.totalQuantity, 3.5);
      expect(stats.completionRate, closeTo(3 / 5, 0.000001));
      expect(stats.weekdayDistribution, _weekdayCounts(dates));
      expect(stats.monthlyAverage, closeTo(3.5 / 30, 0.000001));
      expect(stats.nextMilestone, 1100);
      expect(stats.longestStreak, 2);
      expect(stats.longestStreakStart, _dayFrom(today, -2));
      expect(stats.longestStreakEnd, _dayFrom(today, -1));
    });

    test('uses tracker creation date when a continued tracker has no entries', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tracker = _tracker(
        id: 'empty',
        createdAt: _dayFrom(today, -2),
        streakType: StreakType.continued,
        longestStreak: 4,
      );
      final repository = _StatsEntryRepository([]);
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      final sub = _keepStatsAlive(container, tracker);
      addTearDown(sub.close);

      final stats = await container.read(trackerStatsProvider(tracker).future);

      expect(stats.totalActiveDays, 0);
      expect(stats.totalQuantity, 0);
      expect(stats.completionRate, 0);
      expect(stats.weekdayDistribution, _weekdayCounts(const []));
      expect(stats.monthlyAverage, 0);
      expect(stats.nextMilestone, 7);
      expect(stats.longestStreak, 4);
      expect(stats.longestStreakStart, isNull);
      expect(stats.longestStreakEnd, isNull);
    });
  });
}
