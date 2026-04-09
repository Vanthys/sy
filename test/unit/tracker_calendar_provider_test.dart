import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sy3/data/database.dart';
import 'package:sy3/data/entry_repository.dart';
import 'package:sy3/data/providers.dart';
import 'package:sy3/data/tracker_config.dart';
import 'package:sy3/logic/tracker_calendar_provider.dart';
import 'package:sy3/services/shared_preferences_provider.dart';

class _SaveCall {
  const _SaveCall({
    required this.trackerId,
    required this.date,
    required this.amount,
  });

  final String trackerId;
  final DateTime date;
  final double amount;
}

class _CalendarEntryRepository implements EntryRepository {
  _CalendarEntryRepository(List<Entry> entries) : _entries = List<Entry>.of(entries);

  final List<Entry> _entries;
  final List<_SaveCall> saveCalls = [];

  String? watchedTrackerId;
  DateTime? watchedFrom;
  DateTime? watchedTo;

  String? fetchedTrackerId;
  DateTime? fetchedFrom;
  DateTime? fetchedTo;

  List<Entry> _filterEntries(String trackerId, DateTime from, DateTime to) {
    final normalizedFrom = DateTime(from.year, from.month, from.day);
    final normalizedTo = DateTime(to.year, to.month, to.day);

    return _entries.where((entry) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      return entry.tracker == trackerId &&
          !day.isBefore(normalizedFrom) &&
          !day.isAfter(normalizedTo);
    }).toList();
  }

  @override
  Stream<List<Entry>> watchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) {
    watchedTrackerId = trackerId;
    watchedFrom = from;
    watchedTo = to;
    return Stream.value(_filterEntries(trackerId, from, to));
  }

  @override
  Future<List<Entry>> fetchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) async {
    fetchedTrackerId = trackerId;
    fetchedFrom = from;
    fetchedTo = to;
    return _filterEntries(trackerId, from, to);
  }

  @override
  Future<void> saveEntry(String trackerId, DateTime date, double amount) async {
    final normalized = DateTime(date.year, date.month, date.day);
    saveCalls.add(
      _SaveCall(trackerId: trackerId, date: normalized, amount: amount),
    );

    final index = _entries.indexWhere(
      (entry) =>
          entry.tracker == trackerId &&
          entry.date.year == normalized.year &&
          entry.date.month == normalized.month &&
          entry.date.day == normalized.day,
    );

    if (index != -1) {
      if (amount > 0) {
        final existing = _entries[index];
        _entries[index] = Entry(
          id: existing.id,
          tracker: existing.tracker,
          date: existing.date,
          quantity: amount,
          comment: existing.comment,
          createdAt: existing.createdAt,
          updatedAt: normalized,
        );
      } else {
        _entries.removeAt(index);
      }
      return;
    }

    if (amount > 0) {
      _entries.add(
        Entry(
          id: _entries.length + 1,
          tracker: trackerId,
          date: normalized,
          quantity: amount,
          createdAt: normalized,
          updatedAt: normalized,
        ),
      );
    }
  }

  @override
  Future<void> deleteEntry(int id) => throw UnimplementedError();

  @override
  Future<List<Entry>> loadEntries(String trackerId) => throw UnimplementedError();

  @override
  Future<void> refreshAllStreaks({bool force = false}) =>
      throw UnimplementedError();

  @override
  Future<void> updateTrackerStreaks(String trackerId) =>
      throw UnimplementedError();

  @override
  Stream<List<Entry>> watchEntries(String trackerId) =>
      throw UnimplementedError();
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
  required StreakType streakType,
  required TrackerConfig config,
  required DateTime createdAt,
}) {
  return Tracker(
    id: id,
    title: 'Calendar Tracker',
    streakType: streakType,
    config: config,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

Future<ProviderContainer> _buildContainer(
  _CalendarEntryRepository repository,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      entryRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
}

ProviderSubscription<CalendarState> _watchCalendar(
  ProviderContainer container,
  Tracker tracker,
) {
  return container.listen<CalendarState>(
    trackerCalendarProvider(tracker),
    (previous, next) {},
  );
}

TrackerCalendarNotifier _readNotifier(
  ProviderContainer container,
  Tracker tracker,
) {
  return container.read(trackerCalendarProvider(tracker).notifier);
}

Future<void> _waitForCalendarLoad(
  ProviderContainer container,
  Tracker tracker,
) async {
  for (var i = 0; i < 100; i++) {
    if (!container.read(trackerCalendarProvider(tracker)).isLoading) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  fail('Calendar provider did not finish loading.');
}

Future<void> _waitForMonths(
  ProviderContainer container,
  Tracker tracker,
  int expectedCount,
) async {
  for (var i = 0; i < 100; i++) {
    if (container.read(trackerCalendarProvider(tracker)).months.length ==
        expectedCount) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  final actual = container.read(trackerCalendarProvider(tracker)).months.length;
  fail('Expected $expectedCount months, found $actual.');
}

DayData _findDay(
  ProviderContainer container,
  Tracker tracker,
  DateTime date,
) {
  final normalized = DateTime(date.year, date.month, date.day);
  final state = container.read(trackerCalendarProvider(tracker));

  for (final month in state.months) {
    for (final day in month.days) {
      if (day.date == normalized) {
        return day;
      }
    }
  }

  throw StateError('Day $normalized was not found in calendar state.');
}

void main() {
  group('TrackerCalendarNotifier', () {
    test('builds continued streak state and choice colors from entries', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tracker = _tracker(
        id: 'continued',
        streakType: StreakType.continued,
        createdAt: _dayFrom(today, -5),
        config: const TrackerConfig(
          inputType: InputType.choice,
          optionColors: ['#FF0000', '#00FF00', '#0000FF'],
          streakColors: ['#123456', '#654321'],
        ),
      );
      final repository = _CalendarEntryRepository([
        _entry(
          id: 1,
          trackerId: tracker.id,
          date: _dayFrom(today, -3),
          quantity: 3,
        ),
        _entry(
          id: 2,
          trackerId: tracker.id,
          date: _dayFrom(today, -1),
          quantity: 1,
        ),
        _entry(id: 3, trackerId: tracker.id, date: today, quantity: 2),
      ]);
      final container = await _buildContainer(repository);
      addTearDown(container.dispose);

      final subscription = _watchCalendar(container, tracker);
      addTearDown(subscription.close);
      await _waitForCalendarLoad(container, tracker);

      final todayData = _findDay(container, tracker, today);
      final yesterdayData = _findDay(container, tracker, _dayFrom(today, -1));
      final earlierEntryData = _findDay(container, tracker, _dayFrom(today, -3));

      expect(repository.watchedTrackerId, tracker.id);
      expect(container.read(trackerCalendarProvider(tracker)).months, hasLength(6));
      expect(todayData.inStreak, isTrue);
      expect(todayData.isStreakStart, isFalse);
      expect(todayData.isStreakEnd, isTrue);
      expect(todayData.color, const Color(0xFF00FF00));
      expect(todayData.streakGradient, hasLength(3));
      expect(yesterdayData.inStreak, isTrue);
      expect(yesterdayData.isStreakStart, isTrue);
      expect(yesterdayData.isStreakEnd, isFalse);
      expect(yesterdayData.color, const Color(0xFFFF0000));
      expect(earlierEntryData.inStreak, isFalse);
    });

    test('treats empty abstinence days as the active streak', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tracker = _tracker(
        id: 'abstinence',
        streakType: StreakType.abstinence,
        createdAt: _dayFrom(today, -3),
        config: const TrackerConfig(inputType: InputType.toggle),
      );
      final repository = _CalendarEntryRepository([
        _entry(
          id: 1,
          trackerId: tracker.id,
          date: _dayFrom(today, -3),
          quantity: 1,
        ),
      ]);
      final container = await _buildContainer(repository);
      addTearDown(container.dispose);

      final subscription = _watchCalendar(container, tracker);
      addTearDown(subscription.close);
      await _waitForCalendarLoad(container, tracker);

      final todayData = _findDay(container, tracker, today);
      final yesterdayData = _findDay(container, tracker, _dayFrom(today, -1));
      final twoDaysAgoData = _findDay(container, tracker, _dayFrom(today, -2));
      final incidentData = _findDay(container, tracker, _dayFrom(today, -3));

      expect(todayData.inStreak, isTrue);
      expect(todayData.isStreakEnd, isTrue);
      expect(yesterdayData.inStreak, isTrue);
      expect(twoDaysAgoData.inStreak, isTrue);
      expect(twoDaysAgoData.isStreakStart, isTrue);
      expect(incidentData.inStreak, isFalse);
      expect(todayData.color, Colors.transparent);
    });

    test('loadMorePastMonths fetches an older batch and extends month state', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tracker = _tracker(
        id: 'loader',
        streakType: StreakType.continued,
        createdAt: _dayFrom(today, -20),
        config: const TrackerConfig(),
      );
      final repository = _CalendarEntryRepository([
        _entry(
          id: 1,
          trackerId: tracker.id,
          date: _dayFrom(today, -10),
          quantity: 4,
        ),
        _entry(
          id: 2,
          trackerId: tracker.id,
          date: DateTime(today.year, today.month - 8, 15),
          quantity: 2,
        ),
      ]);
      final container = await _buildContainer(repository);
      addTearDown(container.dispose);

      final subscription = _watchCalendar(container, tracker);
      addTearDown(subscription.close);
      final notifier = _readNotifier(container, tracker);
      await _waitForCalendarLoad(container, tracker);

      final initialEarliest = DateTime(today.year, today.month - 5, 1);
      final expectedNewStart = DateTime(
        initialEarliest.year,
        initialEarliest.month - 6,
        1,
      );

      await notifier.loadMorePastMonths();
      await _waitForMonths(container, tracker, 12);

      expect(repository.fetchedTrackerId, tracker.id);
      expect(repository.fetchedFrom, expectedNewStart);
      expect(
        repository.fetchedTo,
        initialEarliest.add(const Duration(days: 1)),
      );
      expect(repository.watchedFrom, expectedNewStart);
      final state = container.read(trackerCalendarProvider(tracker));
      expect(state.isLoadingMore, isFalse);
      expect(state.months, hasLength(12));
    });

    test('saveEntry with zero on an empty day does not create a phantom entry', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final targetDate = _dayFrom(today, -1);
      final tracker = _tracker(
        id: 'save-zero',
        streakType: StreakType.continued,
        createdAt: _dayFrom(today, -7),
        config: const TrackerConfig(inputType: InputType.number, unit: 'km'),
      );
      final repository = _CalendarEntryRepository([]);
      final container = await _buildContainer(repository);
      addTearDown(container.dispose);

      final subscription = _watchCalendar(container, tracker);
      addTearDown(subscription.close);
      final notifier = _readNotifier(container, tracker);
      await _waitForCalendarLoad(container, tracker);

      await notifier.saveEntry(targetDate, 0);

      final dayData = _findDay(container, tracker, targetDate);

      expect(dayData.entry, isNull);
      expect(dayData.amount, 0);
      expect(repository.saveCalls, hasLength(1));
      expect(repository.saveCalls.single.trackerId, tracker.id);
      expect(repository.saveCalls.single.date, targetDate);
      expect(repository.saveCalls.single.amount, 0);
    });
  });
}
