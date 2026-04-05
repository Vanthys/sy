import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../logic/tracker_stats_provider.dart';
import '../../logic/tracker_overview_provider.dart';
import '../../utils/color_utils.dart';

import 'performance_grid.dart';
import 'activity_trend_chart.dart';
import 'milestone_progress_card.dart';
import 'consistency_matrix_chart.dart';
import 'detailed_records_card.dart';

class TrackerStatsView extends ConsumerWidget {
  const TrackerStatsView({super.key, required this.tracker});

  final Tracker tracker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(trackerStatsProvider(tracker));
    final historyAsync = ref.watch(trackerOverviewProvider(tracker.id));
    final cs = Theme.of(context).colorScheme;

    final accent =
        (tracker.config.intensityColors?.isNotEmpty == true
            ? ColorUtils.parseHexColor(tracker.config.intensityColors!.first)
            : null) ??
        (tracker.streakType == StreakType.continued ? cs.primary : cs.tertiary);

    if (statsAsync.isLoading || historyAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (statsAsync.hasError) {
      return Center(child: Text('Error: ${statsAsync.error}'));
    }

    final stats = statsAsync.value!;
    final history = historyAsync.value ?? [];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Performance Overview'),
          const SizedBox(height: 16),
          PerformanceGrid(tracker: tracker, stats: stats, accent: accent),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Activity Trend (28 Days)'),
          const SizedBox(height: 16),
          ActivityTrendChart(tracker: tracker, data: history, accent: accent),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Milestone Progress'),
          const SizedBox(height: 16),
          MilestoneProgressCard(stats: stats, accent: accent),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Historical Records'),
          const SizedBox(height: 16),
          DetailedRecordsCard(tracker: tracker, stats: stats, accent: accent),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Consistency Matrix'),
          const SizedBox(height: 16),
          ConsistencyMatrixChart(stats: stats, accent: accent),
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.outline,
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
