import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '/data/database.dart';
import '/data/providers.dart';
import '/widgets/tracker_editor_sheet.dart';
import '/widgets/tracker_overview_card.dart';
import 'tracker_calendar_screen.dart';

class TrackerListScreen extends ConsumerStatefulWidget {
  const TrackerListScreen({super.key});

  @override
  ConsumerState<TrackerListScreen> createState() => _TrackerListScreenState();
}

class _TrackerListScreenState extends ConsumerState<TrackerListScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh streaks quietly in the background after the first frame
    Future.microtask(() => ref.read(refreshStreaksProvider.future));
  }

  Future<void> _openTrackerEditor(
    BuildContext context,
    WidgetRef ref, {
    Tracker? existing,
  }) async {
    final repo = ref.read(trackerRepositoryProvider);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TrackerEditorSheet(repo: repo, existingTracker: existing),
    );

    if (result == true && context.mounted) {
      ref.invalidate(refreshStreaksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Tracker created' : 'Tracker updated',
          ),
        ),
      );
    }
  }

  Future<void> _deleteTracker(
    BuildContext context,
    WidgetRef ref,
    Tracker t,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete tracker?'),
        content: Text('This will remove "${t.title}" and all its entries.'),
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
      await ref.read(trackerRepositoryProvider).deleteTracker(t.id);
    }
  }

  Future<void> _exportDatabase(BuildContext context) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final dbPath = p.join(dir.path, AppDatabase.dbName);
      final file = File(dbPath);

      if (await file.exists()) {
        final box = context.findRenderObject() as RenderBox?;
        await Share.shareXFiles(
          [XFile(dbPath)],
          text: 'My Streak Tracker Backup',
          sharePositionOrigin: box != null
              ? box.localToGlobal(Offset.zero) & box.size
              : null,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database file not found!')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(trackerRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trackers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Database',
            onPressed: () => _exportDatabase(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTrackerEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Tracker'),
      ),
      body: StreamBuilder<List<Tracker>>(
        stream: repo.watchAllTrackers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final trackers = snapshot.data!;
          if (trackers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No trackers yet.'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _openTrackerEditor(context, ref),
                    child: const Text('Create your first tracker'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            separatorBuilder: (_, _) => const SizedBox(height: 0),
            itemCount: trackers.length,
            itemBuilder: (context, i) {
              final tracker = trackers[i];

              return TrackerOverviewCard(
                tracker: tracker,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackerCalendarScreen(tracker: tracker),
                    ),
                  );
                },
                onEdit: () =>
                    _openTrackerEditor(context, ref, existing: tracker),
                onDelete: () => _deleteTracker(context, ref, tracker),
              );
            },
          );
        },
      ),
    );
  }
}
