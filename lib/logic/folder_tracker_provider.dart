import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/data/database.dart';
import '/data/providers.dart';
import '/logic/tracker_overview_provider.dart';

/// For a folder tracker, returns [historyDays] doubles where each value is the
/// count of children that logged an entry on that day (oldest → newest).
final folderTrackerOverviewProvider =
    StreamProvider.family<List<double>, Tracker>((ref, folder) async* {
      if (!folder.isFolder || folder.childIds.isEmpty) {
        yield List.filled(historyDays, 0.0);
        return;
      }

      final entryRepo = await ref.watch(entryRepositoryProvider.future);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(
        today.year,
        today.month,
        today.day - (historyDays - 1),
      );

      // Hold the latest snapshot for each child index
      final snapshots = <int, List<Entry>>{};
      final controller = StreamController<List<double>>();

      void rebuild() {
        if (snapshots.length < folder.childIds.length) return;
        final dayMap = <DateTime, int>{
          for (int i = 0; i < historyDays; i++)
            DateTime(start.year, start.month, start.day + i): 0,
        };
        for (final entries in snapshots.values) {
          for (final entry in entries) {
            if (entry.quantity > 0) {
              final d = DateTime(
                entry.date.year,
                entry.date.month,
                entry.date.day,
              );
              if (dayMap.containsKey(d)) dayMap[d] = dayMap[d]! + 1;
            }
          }
        }
        if (!controller.isClosed) {
          controller.add(dayMap.values.map((c) => c.toDouble()).toList());
        }
      }

      final subs = <StreamSubscription<List<Entry>>>[];
      for (var i = 0; i < folder.childIds.length; i++) {
        final index = i;
        final sub = entryRepo
            .watchEntriesInRange(folder.childIds[index], start, today)
            .listen((entries) {
              snapshots[index] = entries;
              rebuild();
            });
        subs.add(sub);
      }

      ref.onDispose(() {
        for (final s in subs) {
          s.cancel();
        }
        controller.close();
      });

      yield* controller.stream;
    });
