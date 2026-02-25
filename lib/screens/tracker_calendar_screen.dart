import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/providers.dart';
import '../widgets/tracker_calendar.dart';

class TrackerCalendarScreen extends ConsumerWidget {
  const TrackerCalendarScreen({
    super.key,
    required this.trackerId,
    required this.trackerTitle,
  });

  final String trackerId;
  final String trackerTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: Text(trackerTitle)),
      body: FutureBuilder<Tracker?>(
        future: (database.select(
          database.trackers,
        )..where((t) => t.id.equals(trackerId))).getSingleOrNull(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load tracker',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          final tracker = snapshot.data;
          if (tracker == null) {
            return const Center(child: Text('Tracker not found.'));
          }

          return TrackerCalendar(tracker: tracker);
        },
      ),
    );
  }
}
