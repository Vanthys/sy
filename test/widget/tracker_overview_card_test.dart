import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy/data/database.dart';
import 'package:sy/data/tracker_config.dart';
import 'package:sy/logic/tracker_overview_provider.dart';
import 'package:sy/widgets/tracker_overview_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Tracker _buildTracker({
  String title = 'Test Tracker',
  int currentStreak = 7,
  int longestStreak = 14,
  StreakType streakType = StreakType.continued,
}) {
  final now = DateTime.now();
  return Tracker(
    id: 'tracker-1',
    title: title,
    streakType: streakType,
    config: const TrackerConfig(),
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    createdAt: now,
    updatedAt: now,
  );
}

/// Wraps [child] in a [ProviderScope] that overrides [trackerOverviewProvider]
/// with a fake that always yields an empty list, and a [MaterialApp].
Widget _buildHarness(Widget child) {
  return ProviderScope(
    overrides: [
      // Override the provider to avoid needing a real database connection.
      trackerOverviewProvider.overrideWith((ref, trackerId) async* {
        yield List<double>.filled(28, 0.0);
      }),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TrackerOverviewCard', () {
    testWidgets('renders tracker title', (tester) async {
      final tracker = _buildTracker(title: 'My Exercise Habit');
      await tester.pumpWidget(
        _buildHarness(
          TrackerOverviewCard(
            tracker: tracker,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Exercise Habit'), findsOneWidget);
    });

    testWidgets('renders current streak count', (tester) async {
      final tracker = _buildTracker(currentStreak: 21);
      await tester.pumpWidget(
        _buildHarness(
          TrackerOverviewCard(
            tracker: tracker,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Current: 21'), findsOneWidget);
    });

    testWidgets('renders longest streak count', (tester) async {
      final tracker = _buildTracker(longestStreak: 42);
      await tester.pumpWidget(
        _buildHarness(
          TrackerOverviewCard(
            tracker: tracker,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Longest: 42'), findsOneWidget);
    });

    testWidgets('onTap fires when card is tapped', (tester) async {
      bool tapped = false;
      final tracker = _buildTracker();
      await tester.pumpWidget(
        _buildHarness(
          TrackerOverviewCard(
            tracker: tracker,
            onTap: () => tapped = true,
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the tracker title area (the InkWell)
      await tester.tap(find.text('Test Tracker'));
      expect(tapped, isTrue);
    });

    testWidgets('shows fire icon for continued tracker', (tester) async {
      final tracker = _buildTracker(streakType: StreakType.continued);
      await tester.pumpWidget(
        _buildHarness(
          TrackerOverviewCard(
            tracker: tracker,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets('shows block icon for abstinence tracker', (tester) async {
      final tracker = _buildTracker(streakType: StreakType.abstinence);
      await tester.pumpWidget(
        _buildHarness(
          TrackerOverviewCard(
            tracker: tracker,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      final now = DateTime.now();
      final tracker = Tracker(
        id: 'tracker-2',
        title: 'Run Daily',
        description: 'Morning jogs',
        streakType: StreakType.continued,
        config: const TrackerConfig(),
        createdAt: now,
        updatedAt: now,
      );
      await tester.pumpWidget(
        _buildHarness(
          TrackerOverviewCard(
            tracker: tracker,
            onTap: () {},
            onEdit: () {},
            onDelete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Morning jogs'), findsOneWidget);
    });
  });
}
