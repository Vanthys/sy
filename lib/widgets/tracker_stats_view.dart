import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database.dart';
import '../logic/tracker_stats_provider.dart';
import '../utils/color_utils.dart';

class TrackerStatsView extends ConsumerWidget {
  const TrackerStatsView({super.key, required this.tracker});

  final Tracker tracker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(trackerStatsProvider(tracker));
    final cs = Theme.of(context).colorScheme;

    final accent =
        (tracker.config.intensityColors?.isNotEmpty == true
            ? ColorUtils.parseHexColor(tracker.config.intensityColors!.first)
            : null) ??
        (tracker.streakType == StreakType.continued ? cs.primary : cs.tertiary);

    return statsAsync.when(
      data: (stats) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'Performance'),
            const SizedBox(height: 16),
            _buildStatGrid(context, stats, accent),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Milestones'),
            const SizedBox(height: 16),
            _buildMilestoneCard(context, stats, accent),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'Weekday Distribution'),
            const SizedBox(height: 16),
            _buildWeekdayDistribution(context, stats, accent),
            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading stats: $err')),
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

  Widget _buildStatGrid(
    BuildContext context,
    TrackerStats stats,
    Color accent,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          label: 'Total Active',
          value: '${stats.totalActiveDays}',
          unit: 'days',
          icon: Icons.calendar_today,
          color: accent,
        ),
        _StatCard(
          label: 'Total Amount',
          value: stats.totalQuantity % 1 == 0
              ? stats.totalQuantity.toInt().toString()
              : stats.totalQuantity.toStringAsFixed(1),
          unit: tracker.config.unit ?? 'units',
          icon: Icons.analytics,
          color: accent,
        ),
        _StatCard(
          label: 'Success Rate',
          value: (stats.completionRate * 100).toStringAsFixed(0),
          unit: '%',
          icon: Icons.auto_graph,
          color: accent,
          showOnlyIf: tracker.streakType == StreakType.continued,
        ),
        _StatCard(
          label: 'Monthly Avg',
          value: stats.monthlyAverage.toStringAsFixed(1),
          unit: '${tracker.config.unit ?? 'units'}/day',
          icon: Icons.speed,
          color: accent,
        ),
      ].where((c) => c.showOnlyIf).toList(),
    );
  }

  Widget _buildMilestoneCard(
    BuildContext context,
    TrackerStats stats,
    Color accent,
  ) {
    final cs = Theme.of(context).colorScheme;
    final progress = stats.currentStreak / stats.nextMilestone;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Milestone',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${stats.nextMilestone} Days',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Icon(Icons.emoji_events, color: accent, size: 32),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: cs.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${stats.currentStreak} days current',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '${stats.nextMilestone - stats.currentStreak} left',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayDistribution(
    BuildContext context,
    TrackerStats stats,
    Color accent,
  ) {
    final cs = Theme.of(context).colorScheme;
    final maxCount = stats.weekdayDistribution.values.fold(
      0,
      (max, v) => v > max ? v : max,
    );
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final dayNum = i + 1;
          final count = stats.weekdayDistribution[dayNum] ?? 0;
          final heightFactor = maxCount == 0 ? 0.0 : count / maxCount;

          return Column(
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: count > 0
                      ? cs.onSurface
                      : cs.onSurfaceVariant.withValues(alpha: 0.5),
                  fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 24,
                height: 80 * heightFactor + 4, // min height of 4
                decoration: BoxDecoration(
                  color: count > 0
                      ? accent.withValues(alpha: 0.2 + (0.8 * heightFactor))
                      : cs.outlineVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                dayNames[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: i >= 5
                      ? FontWeight.bold
                      : FontWeight.normal, // Highlight weekend
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool showOnlyIf;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.showOnlyIf = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
          const Spacer(),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  unit,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
