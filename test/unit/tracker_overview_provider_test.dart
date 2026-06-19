import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy/data/database.dart';
import 'package:sy/data/entry_repository.dart';
import 'package:sy/data/providers.dart';
import 'package:sy/logic/tracker_overview_provider.dart';

class _RecordingEntryRepository implements EntryRepository {
  _RecordingEntryRepository(this.entries);

  final List<Entry> entries;
  String? requestedTrackerId;
  DateTime? requestedStart;
  DateTime? requestedEnd;

  @override
  Stream<List<Entry>> watchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) {
    requestedTrackerId = trackerId;
    requestedStart = from;
    requestedEnd = to;
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
  Stream<List<Entry>> watchEntries(String trackerId) =>
      throw UnimplementedError();
}

DateTime _dayFrom(DateTime anchor, int offset) {
  return DateTime(anchor.year, anchor.month, anchor.day + offset);
}

int _historyIndex(DateTime start, DateTime date) {
  final normalizedDate = DateTime(date.year, date.month, date.day);

  for (int i = 0; i < historyDays; i++) {
    final current = DateTime(start.year, start.month, start.day + i);
    if (current == normalizedDate) {
      return i;
    }
  }

  throw ArgumentError('Date $normalizedDate is outside the history window.');
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

ProviderContainer _buildContainer(_RecordingEntryRepository repository) {
  return ProviderContainer(
    overrides: [
      entryRepositoryProvider.overrideWith((ref) async => repository),
    ],
  );
}

ProviderSubscription<AsyncValue<List<double>>> _keepOverviewAlive(
  ProviderContainer container,
  String trackerId,
) {
  return container.listen<AsyncValue<List<double>>>(
    trackerOverviewProvider(trackerId),
    (previous, next) {},
  );
}

void main() {
  group('trackerOverviewProvider', () {
    test(
      'returns a 28-day ordered history with zeros for missing dates',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final start = _dayFrom(today, -(historyDays - 1));

        final repository = _RecordingEntryRepository([
          _entry(
            id: 1,
            trackerId: 'tracker-1',
            date: _dayFrom(today, 1),
            quantity: 99,
          ),
          _entry(
            id: 2,
            trackerId: 'tracker-1',
            date: _dayFrom(today, -10),
            quantity: 4,
          ),
          _entry(id: 3, trackerId: 'tracker-1', date: start, quantity: 2),
          _entry(id: 4, trackerId: 'tracker-1', date: today, quantity: 7),
          _entry(
            id: 5,
            trackerId: 'tracker-1',
            date: _dayFrom(start, -1),
            quantity: 88,
          ),
        ]);
        final container = _buildContainer(repository);
        addTearDown(container.dispose);
        final sub = _keepOverviewAlive(container, 'tracker-1');
        addTearDown(sub.close);

        final history = await container.read(
          trackerOverviewProvider('tracker-1').future,
        );

        expect(repository.requestedTrackerId, 'tracker-1');
        expect(repository.requestedStart, start);
        expect(repository.requestedEnd, today);
        expect(history, hasLength(historyDays));
        expect(history.first, 2);
        expect(history[_historyIndex(start, _dayFrom(today, -10))], 4);
        expect(history.last, 7);
        expect(history[1], 0);
      },
    );

    test('returns zeros for the full range when no entries exist', () async {
      final repository = _RecordingEntryRepository([]);
      final container = _buildContainer(repository);
      addTearDown(container.dispose);
      final sub = _keepOverviewAlive(container, 'tracker-1');
      addTearDown(sub.close);

      final history = await container.read(
        trackerOverviewProvider('tracker-1').future,
      );

      expect(history, List<double>.filled(historyDays, 0));
    });
  });
}
