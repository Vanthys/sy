import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/database.dart';
import '../../logic/tracker_stats_provider.dart';

class DetailedRecordsCard extends StatelessWidget {
  const DetailedRecordsCard({
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
    final cs = Theme.of(context).colorScheme;
    
    String longestDateStr = 'Not achieved yet';
    if (stats.longestStreak > 0 && stats.longestStreakStart != null && stats.longestStreakEnd != null) {
      final startFn = DateFormat('MMM d, yyyy').format(stats.longestStreakStart!);
      final endFn = DateFormat('MMM d, yyyy').format(stats.longestStreakEnd!);
      if (stats.longestStreakStart == stats.longestStreakEnd) {
        longestDateStr = startFn;
      } else {
        longestDateStr = '$startFn - $endFn';
      }
    }
    
    final createdStr = DateFormat('MMMM d, yyyy').format(tracker.createdAt);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, color: accent, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Longest Streak',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${stats.longestStreak} Days',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (stats.longestStreak > 0) ...[
            const SizedBox(height: 8),
            Text(
              longestDateStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.history, color: cs.primary, size: 24),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tracking Started',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    createdStr,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
