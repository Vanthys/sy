import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/data/database.dart';
import '/data/providers.dart';
import '/widgets/tracker_overview_card.dart';
import '/widgets/tracker_editor_sheet.dart';
import '/logic/vault_provider.dart';
import 'tracker_calendar_screen.dart';

class FolderTrackerScreen extends ConsumerStatefulWidget {
  const FolderTrackerScreen({super.key, required this.folder});

  final Tracker folder;

  @override
  ConsumerState<FolderTrackerScreen> createState() =>
      _FolderTrackerScreenState();
}

class _FolderTrackerScreenState extends ConsumerState<FolderTrackerScreen> {
  List<String>? _pendingOrder;

  @override
  Widget build(BuildContext context) {
    final trackersAsync = ref.watch(trackerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit folder',
            onPressed: () => _openFolderEditor(context),
          ),
        ],
      ),
      body: trackersAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allTrackers) {
          final childOrder = _pendingOrder ?? widget.folder.childIds;
          final children =
              allTrackers.where((t) => childOrder.contains(t.id)).toList()
                ..sort(
                  (a, b) => childOrder.indexOf(a.id) - childOrder.indexOf(b.id),
                );

          if (children.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No trackers in this folder',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => _openFolderEditor(context),
                    child: const Text('Add trackers'),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.folder.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Text(
                    widget.folder.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '${children.length} tracker${children.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  proxyDecorator: (widget, index, animation) =>
                      Material(color: Colors.transparent, child: widget),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                  itemCount: children.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    if (oldIndex == newIndex) return;

                    final reordered = List<String>.from(childOrder);
                    final moved = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, moved);

                    setState(() => _pendingOrder = reordered);

                    final repo = await ref.read(
                      trackerRepositoryProvider.future,
                    );
                    await repo.updateTracker(
                      widget.folder.id,
                      childIds: reordered,
                    );

                    if (mounted) setState(() => _pendingOrder = null);
                  },
                  itemBuilder: (context, i) {
                    final child = children[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(child.id),
                      index: i,
                      child: TrackerOverviewCard(
                        tracker: child,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TrackerCalendarScreen(tracker: child),
                          ),
                        ),
                        onEdit: () => _openChildEditor(context, child),
                        onDelete: () => _deleteChild(context, child),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openFolderEditor(BuildContext context) async {
    final repo = await ref.read(trackerRepositoryProvider.future);
    final vaultState = ref.read(vaultProvider);
    if (!context.mounted) return;

    final latest = await repo.getTrackerById(widget.folder.id) ?? widget.folder;
    if (!context.mounted) return;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TrackerEditorSheet(
        repo: repo,
        vaultState: vaultState,
        existingTracker: latest,
      ),
    );
  }

  Future<void> _openChildEditor(BuildContext context, Tracker child) async {
    final repo = await ref.read(trackerRepositoryProvider.future);
    final vaultState = ref.read(vaultProvider);
    if (!context.mounted) return;

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TrackerEditorSheet(
        repo: repo,
        vaultState: vaultState,
        existingTracker: child,
      ),
    );
  }

  Future<void> _deleteChild(BuildContext context, Tracker child) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete tracker?'),
        content: Text('This will remove "${child.title}" and all its entries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = await ref.read(trackerRepositoryProvider.future);
      await repo.deleteTracker(child.id);
    }
  }
}
