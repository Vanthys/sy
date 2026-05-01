import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/data/database.dart';
import '/data/providers.dart';
import '/logic/tracker_overview_provider.dart';

/// For a folder tracker, returns [historyDays] doubles where each value is the
/// number of children that had a "good day" (oldest → newest).
///
/// A good day is defined per child streak type:
///   - continued  -> has an entry with quantity > 0
///   - abstinence -> has NO entry with quantity > 0
///
/// Max value per day equals childIds.length (all children on track).
final folderTrackerOverviewProvider =
    StreamProvider.family<List<double>, Tracker>((ref, folder) async* {
      if (!folder.isFolder || folder.childIds.isEmpty) {
        yield List.filled(historyDays, 0.0);
        return;
      }

      final entryRepo = await ref.watch(entryRepositoryProvider.future);

      // Fetch tracker list to determine each child's streak type.
      final allTrackers = await ref.watch(trackerListProvider.future);
      final childTypes = {
        for (final t in allTrackers)
          if (folder.childIds.contains(t.id)) t.id: t.streakType,
      };

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = DateTime(
        today.year,
        today.month,
        today.day - (historyDays - 1),
      );

      final days = List.generate(
        historyDays,
        (i) => DateTime(start.year, start.month, start.day + i),
      );

      // Hold the latest entry snapshot for each child index.
      final snapshots = <int, List<Entry>>{};
      final controller = StreamController<List<double>>();

      void rebuild() {
        if (snapshots.length < folder.childIds.length) return;

        final dayCount = <DateTime, int>{for (final d in days) d: 0};

        for (var i = 0; i < folder.childIds.length; i++) {
          final childId = folder.childIds[i];
          final isAbstinence = childTypes[childId] == StreakType.abstinence;
          final entries = snapshots[i] ?? [];

          if (isAbstinence) {
            // Good day = no slip recorded (no entry with quantity > 0).
            for (final day in days) {
              final hasSlip = entries.any((e) {
                final d = DateTime(e.date.year, e.date.month, e.date.day);
                return d == day && e.quantity > 0;
              });
              if (!hasSlip) dayCount[day] = dayCount[day]! + 1;
            }
          } else {
            // Good day = at least one entry with quantity > 0.
            for (final entry in entries) {
              if (entry.quantity > 0) {
                final d = DateTime(
                  entry.date.year,
                  entry.date.month,
                  entry.date.day,
                );
                if (dayCount.containsKey(d)) dayCount[d] = dayCount[d]! + 1;
              }
            }
          }
        }

        if (!controller.isClosed) {
          controller.add(dayCount.values.map((c) => c.toDouble()).toList());
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
