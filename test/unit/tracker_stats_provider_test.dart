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
  Future<List<Entry>> loadEntries(String trackerId) =>
      throw UnimplementedError();

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
  TrackerConfig config = const TrackerConfig(),
  int currentStreak = 0,
  int longestStreak = 0,
}) {
  return Tracker(
    id: id,
    title: 'Tracker',
    streakType: streakType,
    config: config,
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

TrackerStatCard _cardByLabel(TrackerStats stats, String label) {
  return stats.overviewCards.firstWhere((card) => card.label == label);
}

void main() {
  group('trackerStatsProvider', () {
    test(
      'builds numeric stats with active-day monthly average and weekly lifecycle',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final monthStart = DateTime(today.year, today.month, 1);
        final tracker = _tracker(
          id: 'numeric',
          createdAt: _dayFrom(today, -20),
          streakType: StreakType.continued,
          config: const TrackerConfig(inputType: InputType.number, unit: 'km'),
          currentStreak: 8,
        );

        final dates = [
          monthStart,
          _dayFrom(monthStart, 2),
          _dayFrom(today, -10),
          _dayFrom(today, -2),
        ];
        final repository = _StatsEntryRepository([
          _entry(id: 1, trackerId: tracker.id, date: dates[0], quantity: 2),
          _entry(id: 2, trackerId: tracker.id, date: dates[1], quantity: 4),
          _entry(id: 3, trackerId: tracker.id, date: dates[2], quantity: 6),
          _entry(id: 4, trackerId: tracker.id, date: dates[3], quantity: 8),
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

        final stats = await container.read(
          trackerStatsProvider(tracker).future,
        );

        expect(repository.requestedTrackerId, tracker.id);
        expect(stats.family, TrackerStatsFamily.numeric);
        expect(stats.totalActiveDays, 4);
        expect(stats.totalQuantity, 20);
        expect(stats.completionRate, closeTo(4 / 22, 0.000001));
        expect(stats.weekdayDistribution, _weekdayCounts(dates));
        expect(stats.lifecycle.granularity, LifecycleGranularity.week);
        expect(stats.lifecycle.series.single.values, [6, 6, 8, 0]);
        expect(_cardByLabel(stats, 'Avg This Month').value, '5');
        expect(_cardByLabel(stats, 'Avg This Month').unit, 'km');
        expect(stats.longestStreak, 1);
      },
    );

    test(
      'builds toggle stats without duplicate totals and picks most recent best bucket on tie',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tracker = _tracker(
          id: 'toggle',
          createdAt: _dayFrom(today, -27),
          streakType: StreakType.continued,
          config: const TrackerConfig(inputType: InputType.toggle),
        );

        final repository = _StatsEntryRepository([
          _entry(
            id: 1,
            trackerId: tracker.id,
            date: _dayFrom(today, -20),
            quantity: 1,
          ),
          _entry(
            id: 2,
            trackerId: tracker.id,
            date: _dayFrom(today, -18),
            quantity: 1,
          ),
          _entry(
            id: 3,
            trackerId: tracker.id,
            date: _dayFrom(today, -5),
            quantity: 1,
          ),
          _entry(
            id: 4,
            trackerId: tracker.id,
            date: _dayFrom(today, -1),
            quantity: 1,
          ),
        ]);

        final container = _buildContainer(repository);
        addTearDown(container.dispose);
        final sub = _keepStatsAlive(container, tracker);
        addTearDown(sub.close);

        final stats = await container.read(
          trackerStatsProvider(tracker).future,
        );

        expect(stats.family, TrackerStatsFamily.toggle);
        expect(stats.overviewCards.map((card) => card.label), [
          'Total Completions',
          'Success Rate',
          'Times This Month',
          'Best Month',
        ]);
        expect(_cardByLabel(stats, 'Total Completions').value, '4');
        expect(_cardByLabel(stats, 'Times This Month').value, '4');
        expect(_cardByLabel(stats, 'Best Month').value, 'W4');
        expect(_cardByLabel(stats, 'Best Month').unit, '2 days');
        expect(stats.lifecycle.series.single.values, [0, 2, 0, 2]);
      },
    );

    test(
      'builds abstinence stats with days since last lapse and monthly lifecycle buckets',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tracker = _tracker(
          id: 'abstinence',
          createdAt: _dayFrom(today, -130),
          streakType: StreakType.abstinence,
          currentStreak: 17,
        );

        final lapseDates = [
          _dayFrom(today, -100),
          _dayFrom(today, -45),
          _dayFrom(today, -10),
        ];
        final repository = _StatsEntryRepository([
          _entry(
            id: 1,
            trackerId: tracker.id,
            date: lapseDates[0],
            quantity: 1,
          ),
          _entry(
            id: 2,
            trackerId: tracker.id,
            date: lapseDates[1],
            quantity: 1,
          ),
          _entry(
            id: 3,
            trackerId: tracker.id,
            date: lapseDates[2],
            quantity: 1,
          ),
        ]);

        final container = _buildContainer(repository);
        addTearDown(container.dispose);
        final sub = _keepStatsAlive(container, tracker);
        addTearDown(sub.close);

        final stats = await container.read(
          trackerStatsProvider(tracker).future,
        );

        expect(stats.family, TrackerStatsFamily.abstinence);
        expect(stats.lifecycle.granularity, LifecycleGranularity.month);
        expect(stats.daysSinceLastLapse, 10);
        expect(_cardByLabel(stats, 'Days Since Last Lapse').value, '10');
        expect(
          _cardByLabel(stats, 'Longest Streak').value,
          stats.longestStreak.toString(),
        );
        expect(stats.completionRate, closeTo((130 - 3) / 130, 0.000001));
        expect(stats.lifecycle.series.single.values.reduce((a, b) => a + b), 3);
      },
    );

    test(
      'builds choice stats with deterministic top choices and stacked lifecycle counts',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final monthStart = DateTime(today.year, today.month, 1);
        final tracker = _tracker(
          id: 'choice',
          createdAt: _dayFrom(today, -18),
          streakType: StreakType.continued,
          config: const TrackerConfig(
            inputType: InputType.choice,
            options: ['Good', 'Okay', 'Bad'],
            optionColors: ['#00FF00', '#FFB300', '#FF5252'],
          ),
        );

        final repository = _StatsEntryRepository([
          _entry(
            id: 1,
            trackerId: tracker.id,
            date: _dayFrom(monthStart, -2),
            quantity: 2,
          ),
          _entry(id: 2, trackerId: tracker.id, date: monthStart, quantity: 1),
          _entry(
            id: 3,
            trackerId: tracker.id,
            date: _dayFrom(monthStart, 1),
            quantity: 2,
          ),
          _entry(
            id: 4,
            trackerId: tracker.id,
            date: _dayFrom(monthStart, 2),
            quantity: 1,
          ),
          _entry(
            id: 5,
            trackerId: tracker.id,
            date: _dayFrom(today, -1),
            quantity: 3,
          ),
        ]);

        final container = _buildContainer(repository);
        addTearDown(container.dispose);
        final sub = _keepStatsAlive(container, tracker);
        addTearDown(sub.close);

        final stats = await container.read(
          trackerStatsProvider(tracker).future,
        );

        expect(stats.family, TrackerStatsFamily.choice);
        expect(stats.topChoice?.label, 'Good');
        expect(stats.topChoice?.count, 2);
        expect(stats.topChoiceThisMonth?.label, 'Good');
        expect(stats.topChoiceThisMonth?.count, 2);
        expect(stats.lifecycle.isStacked, isTrue);
        expect(stats.lifecycle.series.map((series) => series.label).toList(), [
          'Good',
          'Okay',
          'Bad',
        ]);
        expect(_cardByLabel(stats, 'Top Choice').value, 'Good');
        expect(_cardByLabel(stats, 'Top Choice This Month').value, 'Good');
      },
    );

    test(
      'uses tracker creation date for empty or zero-only trackers',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tracker = _tracker(
          id: 'empty',
          createdAt: _dayFrom(today, -2),
          streakType: StreakType.continued,
          longestStreak: 4,
        );

        final repository = _StatsEntryRepository([
          _entry(
            id: 1,
            trackerId: tracker.id,
            date: _dayFrom(today, -1),
            quantity: 0,
          ),
        ]);
        final container = _buildContainer(repository);
        addTearDown(container.dispose);
        final sub = _keepStatsAlive(container, tracker);
        addTearDown(sub.close);

        final stats = await container.read(
          trackerStatsProvider(tracker).future,
        );

        expect(stats.totalActiveDays, 0);
        expect(stats.totalQuantity, 0);
        expect(stats.completionRate, 0);
        expect(stats.weekdayDistribution, _weekdayCounts(const []));
        expect(stats.trackingStart, _dayFrom(today, -2));
        expect(stats.longestStreak, 4);
        expect(stats.longestStreakStart, isNull);
        expect(stats.longestStreakEnd, isNull);
        expect(_cardByLabel(stats, 'Avg This Month').value, '0');
      },
    );

    test('shows never for abstinence trackers without lapses', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tracker = _tracker(
        id: 'clean',
        createdAt: _dayFrom(today, -14),
        streakType: StreakType.abstinence,
      );

      final repository = _StatsEntryRepository([]);
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      final sub = _keepStatsAlive(container, tracker);
      addTearDown(sub.close);

      final stats = await container.read(trackerStatsProvider(tracker).future);

      expect(stats.daysSinceLastLapse, isNull);
      expect(_cardByLabel(stats, 'Days Since Last Lapse').value, 'Never');
      expect(stats.lifecycle.isEmpty, isTrue);
    });
  });
}
