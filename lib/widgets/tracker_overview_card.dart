import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/data/database.dart';
import '/logic/tracker_overview_provider.dart';
import '/logic/folder_tracker_provider.dart';
import '/utils/color_utils.dart';
import '/data/tracker_config.dart';

class TrackerOverviewCard extends ConsumerWidget {
  const TrackerOverviewCard({
    super.key,
    required this.tracker,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onRemoveFromFolder,
  });

  final Tracker tracker;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRemoveFromFolder;

  static const int _gridRows = 4;
  static const int _gridCols = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final accent =
        (tracker.config.intensityColors?.isNotEmpty == true
            ? ColorUtils.parseHexColor(tracker.config.intensityColors!.first)
            : null) ??
        (tracker.isFolder
            ? cs.secondary
            : tracker.streakType == StreakType.continued
            ? cs.primary
            : cs.tertiary);

    final asyncData = tracker.isFolder
        ? ref.watch(folderTrackerOverviewProvider(tracker))
        : ref.watch(trackerOverviewProvider(tracker.id));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: tracker.isFolder
            ? cs.secondaryContainer.withValues(alpha: 0.4)
            : cs.surfaceContainerHighest,
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
                asyncData.when(
                  data: (dailyValues) => dailyValues.isNotEmpty
                      ? _buildGrid(context, dailyValues, accent)
                      : const SizedBox.shrink(),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => const Text('Error loading history'),
                ),
              ],
            ),
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

    final iconData = tracker.isFolder
        ? Icons.folder_open
        : tracker.streakType == StreakType.continued
        ? Icons.local_fire_department
        : Icons.block;

    final iconBg = tracker.isFolder
        ? cs.secondaryContainer.withValues(alpha: 0.50)
        : (tracker.streakType == StreakType.continued
                  ? cs.primaryContainer
                  : cs.tertiaryContainer)
              .withValues(alpha: 0.30);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, color: accent),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      tracker.title,
                      softWrap: true,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (tracker.privacyLevel != PrivacyLevel.standard) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0, left: 6.0),
                      child: Icon(
                        tracker.privacyLevel == PrivacyLevel.vault
                            ? Icons.lock_outline
                            : Icons.visibility_off,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
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
              if (tracker.isFolder)
                _Stat(
                  icon: Icons.account_tree_outlined,
                  label:
                      '${tracker.childIds.length} tracker${tracker.childIds.length == 1 ? '' : 's'}',
                  color: accent,
                )
              else
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
            if (value == 'remove_from_folder') onRemoveFromFolder?.call();
            if (value == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            if (onRemoveFromFolder != null)
              const PopupMenuItem(
                value: 'remove_from_folder',
                child: Row(
                  children: [
                    Icon(Icons.folder_off_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Remove from folder'),
                  ],
                ),
              ),
            const PopupMenuItem(
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
    final config = tracker.config;

    final fallbackMax = data.isEmpty
        ? 1.0
        : data.reduce((a, b) => a > b ? a : b);
    final maxVal = tracker.isFolder
        ? (tracker.childIds.isEmpty ? 1.0 : tracker.childIds.length.toDouble())
        : (config.intensityGoal ?? config.maxValue ?? fallbackMax);

    final cells = List<double>.generate(_gridRows * _gridCols, (i) {
      final index = data.length - 1 - i;
      return index >= 0 && index < data.length ? data[index] : 0.0;
    });

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: List.generate(cells.length, (i) {
        final amount = cells[i];

        Color color;

        if (amount <= 0) {
          color = cs.outlineVariant;
        } else if (config.inputType == InputType.toggle) {
          color = accent;
        } else if (config.inputType == InputType.choice) {
          final choiceIndex = (amount - 1).toInt();
          color = ColorUtils.getColorForChoice(
            choiceIndex,
            optionColors: config.optionColors,
            fallback: accent,
          );
        } else {
          final ratio = (amount / (maxVal <= 0 ? 1.0 : maxVal)).clamp(0.0, 1.0);
          color = accent.withValues(alpha: 0.30 + (ratio * 0.70));
        }

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

  const _Stat({required this.icon, required this.label, required this.color});

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
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
