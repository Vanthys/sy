import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../widgets/tracker_calendar.dart';

class TrackerCalendarScreen extends ConsumerWidget {
  const TrackerCalendarScreen({super.key, required this.tracker});

  final Tracker tracker;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(tracker.title)),
      body: TrackerCalendar(tracker: tracker),
    );
  }
}
