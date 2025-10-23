import 'package:flutter/material.dart';
import '/data/database.dart';
import '/data/entry_repository.dart';

class TrackerOverviewCard extends StatelessWidget {
  const TrackerOverviewCard({
    super.key,
    required this.tracker,
    required this.database,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Tracker tracker;
  final AppDatabase database;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const int _gridRows = 4;
  static const int _gridCols = 7;

  @override
  Widget build(BuildContext context) {
    final repo = EntryRepository(database);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - 1, now.day);

    final cs = Theme.of(context).colorScheme;
    final accent = tracker.streakType == StreakType.continued
        ? cs.primary
        : cs.tertiary;

    return StreamBuilder<List<Entry>>(
      stream: repo.watchEntriesInRange(tracker.id, from, now),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        // Inside the StreamBuilder:
final now = DateTime.now();
final start = now.subtract(const Duration(days: 27));

// Create map of all last 28 days initialized to 0
final dayMap = {
  for (int i = 0; i < 28; i++)
    DateTime(start.year, start.month, start.day + i): 0.0
};

// Fill in tracked quantities
for (final entry in entries) {
  final d = DateTime(entry.date.year, entry.date.month, entry.date.day);
  if (d.isAfter(start.subtract(const Duration(days: 1))) &&
      d.isBefore(now.add(const Duration(days: 1)))) {
    dayMap[d] = entry.quantity;
  }
}

// Convert to ordered list oldest → newest
final recentActivity = dayMap.entries.toList()
  ..sort((a, b) => a.key.compareTo(b.key));
final dailyValues = recentActivity.map((e) => e.value).toList().reversed.toList();


        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8), // small gap
          child: Material(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
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
                    if (dailyValues.isNotEmpty)
                      _buildGrid(context, dailyValues, accent),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
            ? cs.outlineVariant
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
