import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../logic/tracker_stats_provider.dart';

class PerformanceGrid extends StatelessWidget {
  const PerformanceGrid({
    super.key,
    required this.tracker,
    required this.stats,
    required this.accent,
  });

  final Tracker tracker;
  final TrackerStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          label: tracker.streakType == StreakType.continued
              ? 'Total Active'
              : 'Total Lapses',
          value: '${stats.totalActiveDays}',
          unit: 'days',
          icon: tracker.streakType == StreakType.continued
              ? Icons.calendar_today
              : Icons.warning_amber_rounded,
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
        ),
        _StatCard(
          label: 'Monthly Avg',
          value: stats.monthlyAverage.toStringAsFixed(1),
          unit: '${tracker.config.unit ?? 'u'}/d',
          icon: Icons.speed,
          color: accent,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
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
