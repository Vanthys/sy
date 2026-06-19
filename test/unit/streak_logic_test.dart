// Unit tests for the public computeStreaks function in streak_logic.dart.
// All tests are pure Dart — no Isar, no Flutter binding required.
import 'package:flutter_test/flutter_test.dart';
import 'package:sy/data/database.dart';
import 'package:sy/data/streak_logic.dart';
import 'package:sy/data/tracker_config.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Tracker _makeTracker({
  StreakType streakType = StreakType.continued,
  DateTime? createdAt,
}) {
  final now = DateTime.now();
  final created = createdAt ?? DateTime(now.year, now.month, now.day);
  return Tracker(
    id: 'test-id',
    title: 'Test Tracker',
    streakType: streakType,
    config: const TrackerConfig(),
    createdAt: created,
    updatedAt: created,
  );
}

/// Creates a minimal [Entry] on the given [date] with [quantity].
Entry _makeEntry(DateTime date, {double quantity = 1.0}) {
  final normalized = DateTime(date.year, date.month, date.day);
  return Entry(
    id: 0,
    tracker: 'test-id',
    date: normalized,
    quantity: quantity,
    createdAt: normalized,
    updatedAt: normalized,
  );
}

// ---------------------------------------------------------------------------
// Continued Tracker Tests
// ---------------------------------------------------------------------------
void main() {
  group('computeStreaks — continued tracker', () {
    test('no entries → (0, 0)', () {
      final tracker = _makeTracker();
      final (current, longest) = computeStreaks(tracker, []);
      expect(current, 0);
      expect(longest, 0);
    });

    test('single entry today → (1, 1)', () {
      final today = DateTime.now();
      final tracker = _makeTracker(createdAt: today);
      final entries = [_makeEntry(today)];

      final (current, longest) = computeStreaks(tracker, entries);
      expect(current, 1);
      expect(longest, 1);
    });

    test('consecutive days ending today → streak equals day count', () {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final twoDaysAgo = DateTime(today.year, today.month, today.day - 2);
      final tracker = _makeTracker(createdAt: twoDaysAgo);
      final entries = [
        _makeEntry(twoDaysAgo),
        _makeEntry(yesterday),
        _makeEntry(today),
      ];

      final (current, longest) = computeStreaks(tracker, entries);
      expect(current, 3);
      expect(longest, 3);
    });

    test('gap yesterday → current = 0, longest preserved', () {
      final today = DateTime.now();
      final twoDaysAgo = DateTime(today.year, today.month, today.day - 2);
      // Logged day-2 and today, NOT yesterday → current streak = 1
      final tracker = _makeTracker(createdAt: twoDaysAgo);
      final entries = [_makeEntry(twoDaysAgo), _makeEntry(today)];

      final (current, longest) = computeStreaks(tracker, entries);
      // Today is logged so current streak = 1
      expect(current, 1);
      // Longest run was 1 (twoDaysAgo) or 1 (today) → both 1
      expect(longest, 1);
    });

    test('entries with quantity=0 are ignored for streak', () {
      final today = DateTime.now();
      final tracker = _makeTracker(createdAt: today);
      // quantity == 0 → should not count
      final entries = [_makeEntry(today, quantity: 0.0)];

      final (current, longest) = computeStreaks(tracker, entries);
      expect(current, 0);
      expect(longest, 0);
    });

    test('longest streak found in past even when current is broken', () {
      final today = DateTime.now();
      // Create tracker 5 days ago; entries days-5,4,3 then a gap, entry today
      final d5 = DateTime(today.year, today.month, today.day - 5);
      final d4 = DateTime(today.year, today.month, today.day - 4);
      final d3 = DateTime(today.year, today.month, today.day - 3);
      final tracker = _makeTracker(createdAt: d5);
      final entries = [
        _makeEntry(d5),
        _makeEntry(d4),
        _makeEntry(d3),
        _makeEntry(today),
      ];

      final (current, longest) = computeStreaks(tracker, entries);
      expect(current, 1); // today only
      expect(longest, 3); // d5→d4→d3 consecutive
    });
  });

  // ---------------------------------------------------------------------------
  // Abstinence Tracker Tests
  // ---------------------------------------------------------------------------
  group('computeStreaks — abstinence tracker', () {
    test('no entries → streak equals days since creation', () {
      final threeDaysAgo = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day - 3,
      );
      final tracker = _makeTracker(
        streakType: StreakType.abstinence,
        createdAt: threeDaysAgo,
      );

      final (current, longest) = computeStreaks(tracker, []);
      // 3 days ago + today = 4 days
      expect(current, 4);
      expect(longest, 4);
    });

    test('entry yesterday breaks current streak', () {
      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final twoDaysAgo = DateTime(today.year, today.month, today.day - 2);
      final tracker = _makeTracker(
        streakType: StreakType.abstinence,
        createdAt: twoDaysAgo,
      );
      // Logged yesterday → streak broken
      final entries = [_makeEntry(yesterday)];

      final (current, longest) = computeStreaks(tracker, entries);
      expect(current, 1); // only today is "good" (no entry)
      expect(longest, 1); // twoDaysAgo was good too before yesterday, so...
      // Actually: twoDaysAgo=good, yesterday=bad, today=good → longest=1
    });

    test('entry today reduces current streak to 0', () {
      final today = DateTime.now();
      final tracker = _makeTracker(
        streakType: StreakType.abstinence,
        createdAt: DateTime(today.year, today.month, today.day - 2),
      );
      // Logged today → today is "bad"
      final entries = [_makeEntry(today)];

      final (current, longest) = computeStreaks(tracker, entries);
      expect(current, 0); // today is bad, current streak = 0
    });
  });
}
