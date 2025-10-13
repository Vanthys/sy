import 'package:flutter/material.dart';
import '/data/database.dart';

class TrackerOverviewCard extends StatelessWidget {
  const TrackerOverviewCard({
    super.key,
    required this.tracker,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.recentActivity,
  });

  final Tracker tracker;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final List<double>? recentActivity;

  static const int _gridRows = 4;
  static const int _gridCols = 7;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = tracker.streakType == StreakType.continued
        ? cs.primary
        : cs.tertiary;

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias, // ensures ripple + shadow clip cleanly
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, accent),
              const SizedBox(height: 12),
              if (recentActivity != null && recentActivity!.isNotEmpty)
                _buildGrid(context, recentActivity!, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final desc = tracker.description?.isNotEmpty == true
        ? tracker.description
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leading icon box
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: (tracker.streakType == StreakType.continued
                    ? cs.primaryContainer
                    : cs.tertiaryContainer)
                .withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            tracker.streakType == StreakType.continued
                ? Icons.local_fire_department
                : Icons.block,
            color: accent,
          ),
        ),

        // Title / desc / stats column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tracker.title,
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              if (desc != null)
                Text(
                  desc,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Stat(
                    icon: Icons.repeat,
                    label: 'Current: ${tracker.currentStreak}',
                    color: accent,
                  ),
                  _Stat(
                    icon: Icons.emoji_events,
                    label: 'Longest: ${tracker.longestStreak}',
                    color: accent,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Popup menu
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert, size: 20),
        ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context, List<double> data, Color accent) {
    final cs = Theme.of(context).colorScheme;

    final maxVal = data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b);
    final normalized = data.map((v) => v / (maxVal == 0 ? 1 : maxVal)).toList();

    // Pad to 7×4 = 28 cells
    final cells = List<double>.generate(_gridRows * _gridCols, (i) {
      final index = data.length - _gridCols * _gridRows + i;
      return index >= 0 && index < data.length ? normalized[index] : 0;
    });

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(cells.length, (i) {
        final value = cells[i];
        final color = value == 0
            ? cs.surfaceContainerHighest
            : accent.withValues(alpha: 0.30 + (value * 0.70));
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Stat({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
