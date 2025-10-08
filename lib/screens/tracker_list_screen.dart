// lib/screens/tracker_list_screen.dart


import 'package:flutter/material.dart';

import '../data/database.dart';
import '../widgets/tracker_editor_dialog.dart';

import 'tracker_calendar_screen.dart';

class TrackerListScreen extends StatefulWidget {
  const TrackerListScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<TrackerListScreen> createState() => _TrackerListScreenState();
}

class _TrackerListScreenState extends State<TrackerListScreen> {
  Future<void> _showCreateTrackerDialog() async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => TrackerEditorDialog(database: widget.database),
  );
  if (result == true && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracker created')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trackers')),
      body: StreamBuilder<List<Tracker>>(
        stream: widget.database.select(widget.database.trackers).watch(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load trackers',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          final trackers = snapshot.data;

          if (trackers == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (trackers.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No trackers yet.'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _showCreateTrackerDialog,
                    child: const Text('Create your first tracker'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: trackers.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final tracker = trackers[index];
              final subtitleParts = <String>[
                if (tracker.description != null && tracker.description!.isNotEmpty)
                  tracker.description!,
                'Current streak: ${tracker.currentStreak}',
                'Longest streak: ${tracker.longestStreak}',
              ];

              return ListTile(
                title: Text(tracker.title),
                subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join('\n')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrackerCalendarScreen(
                        trackerId: tracker.id,
                        trackerTitle: tracker.title,
                        database: widget.database,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTrackerDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
