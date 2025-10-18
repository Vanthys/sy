import 'package:flutter/material.dart';
import '/data/database.dart';
import '/data/tracker_repository.dart';
import '/widgets/tracker_editor_sheet.dart';
import '/widgets/tracker_overview_card.dart';
import 'tracker_calendar_screen.dart';

class TrackerListScreen extends StatefulWidget {
  const TrackerListScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<TrackerListScreen> createState() => _TrackerListScreenState();
}

class _TrackerListScreenState extends State<TrackerListScreen> {
  late final TrackerRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = TrackerRepository(widget.database);
  }

  Future<void> _openTrackerEditor({Tracker? existing}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TrackerEditorSheet(
        repo: _repo,
        existingTracker: existing,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Tracker created' : 'Tracker updated',
          ),
        ),
      );
    }
  }

  Future<void> _deleteTracker(Tracker t) async {
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
      await _repo.deleteTracker(t.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trackers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTrackerEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New Tracker'),
      ),
      body: StreamBuilder<List<Tracker>>(
        stream: _repo.watchAllTrackers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading trackers'));
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
                    onPressed: () => _openTrackerEditor(),
                    child: const Text('Create your first tracker'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            separatorBuilder: (_, __) => const SizedBox(height: 0),
            itemCount: trackers.length,
            itemBuilder: (context, i) {
              final tracker = trackers[i];

              return TrackerOverviewCard(
                tracker: tracker,
                database: widget.database, // 🔗 inject database for auto-loading
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TrackerCalendarScreen(
                        trackerId: tracker.id,
                        trackerTitle: tracker.title,
                        database: widget.database,
                      ),
                    ),
                  );
                },
                onEdit: () => _openTrackerEditor(existing: tracker),
                onDelete: () => _deleteTracker(tracker),
              );
            },
          );
        },
      ),
    );
  }
}
