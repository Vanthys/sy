import 'package:flutter/material.dart';

import '../data/database.dart';
import '../widgets/tracker_calendar.dart';

class TrackerCalendarScreen extends StatelessWidget {
  const TrackerCalendarScreen({
    super.key,
    required this.trackerId,
    required this.trackerTitle,
    required this.database,
  });

  final String trackerId;
  final String trackerTitle;
  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
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

          return TrackerCalendar(
            trackerId: trackerId,
            database: database,
            unitName: tracker.unitName,
            unitAbbreviation: tracker.unitAbbreviation,
          );
        },
      ),
    );
  }
}
