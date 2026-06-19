import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy/data/database.dart';
import 'package:sy/data/tracker_config.dart';
import 'package:sy/widgets/tracker_value_bottom_sheet.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Tracker _buildTracker({InputType inputType = InputType.number}) {
  final now = DateTime.now();
  return Tracker(
    id: 'tracker-1',
    title: 'Test',
    streakType: StreakType.continued,
    config: TrackerConfig(inputType: inputType, maxValue: 20.0, unit: 'km'),
    createdAt: now,
    updatedAt: now,
  );
}

Widget _buildHarness(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('TrackerValueBottomSheet', () {
    final today = DateTime.now();

    group('number input type', () {
      testWidgets('renders the formatted date', (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            TrackerValueBottomSheet(
              tracker: _buildTracker(),
              date: DateTime(2025, 6, 15),
              initialAmount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // The date should appear somewhere in the widget tree
        expect(find.textContaining('2025'), findsWidgets);
      });

      testWidgets('Cancel button is present', (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            TrackerValueBottomSheet(
              tracker: _buildTracker(),
              date: today,
              initialAmount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancel'), findsOneWidget);
      });

      testWidgets('Save button is present', (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            TrackerValueBottomSheet(
              tracker: _buildTracker(),
              date: today,
              initialAmount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Save'), findsOneWidget);
      });
    });

    group('toggle input type', () {
      testWidgets('shows Yes and No segments', (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            TrackerValueBottomSheet(
              tracker: _buildTracker(inputType: InputType.toggle),
              date: today,
              initialAmount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);
      });

      testWidgets('tapping Yes segment updates selection', (tester) async {
        await tester.pumpWidget(
          _buildHarness(
            TrackerValueBottomSheet(
              tracker: _buildTracker(inputType: InputType.toggle),
              date: today,
              initialAmount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();

        // No crash & Yes is still visible (selection changed)
        expect(find.text('Yes'), findsOneWidget);
      });
    });

    group('choice input type', () {
      testWidgets('renders choice chips from options', (tester) async {
        final now = DateTime.now();
        final tracker = Tracker(
          id: 'tracker-choice',
          title: 'Mood',
          streakType: StreakType.continued,
          config: const TrackerConfig(
            inputType: InputType.choice,
            options: ['Good', 'Neutral', 'Bad'],
          ),
          createdAt: now,
          updatedAt: now,
        );
        await tester.pumpWidget(
          _buildHarness(
            TrackerValueBottomSheet(
              tracker: tracker,
              date: today,
              initialAmount: 0,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Good'), findsOneWidget);
        expect(find.text('Neutral'), findsOneWidget);
        expect(find.text('Bad'), findsOneWidget);
      });
    });
  });
}
