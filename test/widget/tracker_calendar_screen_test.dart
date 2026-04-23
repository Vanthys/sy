import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sy3/data/database.dart';
import 'package:sy3/data/entry_repository.dart';
import 'package:sy3/data/providers.dart';
import 'package:sy3/data/tracker_config.dart';
import 'package:sy3/logic/tracker_stats_provider.dart';
import 'package:sy3/logic/vault_provider.dart';
import 'package:sy3/screens/tracker_calendar_screen.dart';
import 'package:sy3/services/shared_preferences_provider.dart';

class _FakeEntryRepository implements EntryRepository {
  @override
  Future<void> deleteEntry(int id) async {}

  @override
  Future<List<Entry>> fetchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) async => [];

  @override
  Future<List<Entry>> loadEntries(String trackerId) async => [];

  @override
  Future<void> refreshAllStreaks({bool force = false}) async {}

  @override
  Future<void> saveEntry(
    String trackerId,
    DateTime date,
    double amount,
  ) async {}

  @override
  Future<void> updateTrackerStreaks(String trackerId) async {}

  @override
  Stream<List<Entry>> watchEntries(String trackerId) => Stream.value([]);

  @override
  Stream<List<Entry>> watchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) => Stream.value([]);
}

class _TestVaultNotifier extends VaultNotifier {
  _TestVaultNotifier(this._testState);

  VaultState _testState;

  @override
  VaultState build() => _testState;

  void setStateForTest(VaultState newState) {
    _testState = newState;
    state = newState;
  }
}

Tracker _buildTracker({
  PrivacyLevel privacyLevel = PrivacyLevel.standard,
  String title = 'Tracker',
  StreakType streakType = StreakType.continued,
  TrackerConfig config = const TrackerConfig(),
}) {
  final now = DateTime.now();
  return Tracker(
    id: 'tracker-1',
    title: title,
    streakType: streakType,
    privacyLevel: privacyLevel,
    config: config,
    createdAt: now,
    updatedAt: now,
  );
}

TrackerStats _buildStats({
  TrackerStatsFamily family = TrackerStatsFamily.numeric,
  List<TrackerStatCard>? overviewCards,
}) {
  return TrackerStats(
    family: family,
    overviewCards:
        overviewCards ??
        const [
          TrackerStatCard(
            label: 'Total Amount',
            value: '12',
            unit: 'units',
            icon: Icons.analytics,
          ),
          TrackerStatCard(
            label: 'Active Days',
            value: '5',
            unit: 'days',
            icon: Icons.calendar_today,
          ),
          TrackerStatCard(
            label: 'Success Rate',
            value: '50',
            unit: '%',
            icon: Icons.auto_graph,
          ),
          TrackerStatCard(
            label: 'Avg This Month',
            value: '1.2',
            unit: 'units',
            icon: Icons.speed,
          ),
        ],
    weekdayDistribution: {for (var i = 1; i <= 7; i++) i: 0},
    lifecycle: const LifecycleChartData(
      granularity: LifecycleGranularity.week,
      bucketLabels: ['W1', 'W2'],
      series: [
        LifecycleSeries(label: 'Lifecycle', values: [2, 3]),
      ],
      isStacked: false,
    ),
    nextMilestone: 7,
    currentStreak: 3,
    longestStreak: 6,
    longestStreakStart: DateTime(2026, 1, 1),
    longestStreakEnd: DateTime(2026, 1, 6),
    trackingStart: DateTime(2025, 12, 1),
    totalActiveDays: 5,
    totalQuantity: 12,
    completionRate: 0.5,
    daysSinceLastLapse: null,
    optionTotals: const {},
    monthlyOptionTotals: const {},
    topChoice: null,
    topChoiceThisMonth: null,
  );
}

Future<Widget> _buildApp({
  required Tracker tracker,
  required _TestVaultNotifier vaultNotifier,
  TrackerStats? stats,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWith((ref) => prefs),
      entryRepositoryProvider.overrideWith(
        (ref) async => _FakeEntryRepository(),
      ),
      vaultProvider.overrideWith(() => vaultNotifier),
      trackerStatsProvider.overrideWith((ref, tracker) async* {
        yield stats ?? _buildStats();
      }),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TrackerCalendarScreen(tracker: tracker),
                    ),
                  );
                },
                child: const Text('Open Tracker'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrackerCalendarScreen', () {
    testWidgets(
      'shows privacy icon and toggles between calendar and statistics',
      (tester) async {
        final vaultNotifier = _TestVaultNotifier(
          VaultState(unlockedLevel: PrivacyLevel.vault),
        );

        await tester.pumpWidget(
          await _buildApp(
            tracker: _buildTracker(
              privacyLevel: PrivacyLevel.vault,
              title: 'Private Tracker',
            ),
            vaultNotifier: vaultNotifier,
          ),
        );

        await tester.tap(find.text('Open Tracker'));
        await tester.pumpAndSettle();

        expect(find.text('Private Tracker'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);

        await tester.tap(find.byIcon(Icons.analytics_outlined));
        await tester.pumpAndSettle();

        expect(find.text('Statistics'), findsOneWidget);
        expect(find.byIcon(Icons.calendar_month), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsNothing);
        expect(find.text('PERFORMANCE OVERVIEW'), findsOneWidget);
        expect(find.text('LIFECYCLE TREND'), findsOneWidget);
        expect(find.text('ACTIVITY TREND (28 DAYS)'), findsNothing);
        expect(find.text('Total Amount'), findsOneWidget);
      },
    );

    testWidgets(
      'pops back to previous route when vault locks on a private tracker',
      (tester) async {
        final vaultNotifier = _TestVaultNotifier(
          VaultState(unlockedLevel: PrivacyLevel.vault),
        );

        await tester.pumpWidget(
          await _buildApp(
            tracker: _buildTracker(
              privacyLevel: PrivacyLevel.vault,
              title: 'Private Tracker',
            ),
            vaultNotifier: vaultNotifier,
          ),
        );

        await tester.tap(find.text('Open Tracker'));
        await tester.pumpAndSettle();
        expect(find.text('Private Tracker'), findsOneWidget);

        vaultNotifier.setStateForTest(VaultState());
        await tester.pumpAndSettle();

        expect(find.text('Open Tracker'), findsOneWidget);
        expect(find.text('Private Tracker'), findsNothing);
      },
    );

    testWidgets('stays on screen when vault locks for a standard tracker', (
      tester,
    ) async {
      final vaultNotifier = _TestVaultNotifier(
        VaultState(unlockedLevel: PrivacyLevel.vault),
      );

      await tester.pumpWidget(
        await _buildApp(
          tracker: _buildTracker(title: 'Public Tracker'),
          vaultNotifier: vaultNotifier,
        ),
      );

      await tester.tap(find.text('Open Tracker'));
      await tester.pumpAndSettle();
      expect(find.text('Public Tracker'), findsOneWidget);

      vaultNotifier.setStateForTest(VaultState());
      await tester.pumpAndSettle();

      expect(find.text('Public Tracker'), findsOneWidget);
      expect(find.text('Open Tracker'), findsNothing);
    });

    testWidgets('shows choice-specific overview cards on statistics screen', (
      tester,
    ) async {
      final vaultNotifier = _TestVaultNotifier(VaultState());

      await tester.pumpWidget(
        await _buildApp(
          tracker: _buildTracker(
            title: 'Mood',
            config: const TrackerConfig(
              inputType: InputType.choice,
              options: ['Good', 'Okay', 'Bad'],
            ),
          ),
          vaultNotifier: vaultNotifier,
          stats: _buildStats(
            family: TrackerStatsFamily.choice,
            overviewCards: const [
              TrackerStatCard(
                label: 'Total Logged Days',
                value: '8',
                unit: 'days',
                icon: Icons.event_note,
              ),
              TrackerStatCard(
                label: 'Top Choice',
                value: 'Good',
                unit: '5 times',
                icon: Icons.pie_chart_outline,
              ),
              TrackerStatCard(
                label: 'Top Choice This Month',
                value: 'Okay',
                unit: '3 times',
                icon: Icons.calendar_view_month,
              ),
              TrackerStatCard(
                label: 'Success Rate',
                value: '67',
                unit: '%',
                icon: Icons.auto_graph,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Open Tracker'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.analytics_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Top Choice'), findsOneWidget);
      expect(find.text('Top Choice This Month'), findsOneWidget);
      expect(find.text('Total Logged Days'), findsOneWidget);
    });

    testWidgets('renders abstinence numeric lifecycle as a line chart', (
      tester,
    ) async {
      final vaultNotifier = _TestVaultNotifier(VaultState());

      await tester.pumpWidget(
        await _buildApp(
          tracker: _buildTracker(
            title: 'Smoking',
            streakType: StreakType.abstinence,
            config: const TrackerConfig(
              inputType: InputType.number,
              unit: 'cigs',
            ),
          ),
          vaultNotifier: vaultNotifier,
          stats: _buildStats(
            family: TrackerStatsFamily.abstinence,
            overviewCards: const [
              TrackerStatCard(
                label: 'Total Lapses',
                value: '5',
                unit: 'days',
                icon: Icons.warning_amber_rounded,
              ),
              TrackerStatCard(
                label: 'Days Since Last Lapse',
                value: '3',
                unit: 'days',
                icon: Icons.timelapse,
              ),
              TrackerStatCard(
                label: 'Success Rate',
                value: '80',
                unit: '%',
                icon: Icons.auto_graph,
              ),
              TrackerStatCard(
                label: 'Longest Streak',
                value: '12',
                unit: 'days',
                icon: Icons.local_fire_department,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Open Tracker'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.analytics_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(LineChart), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
    });
  });
}
