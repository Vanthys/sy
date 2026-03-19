import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/data/providers.dart';

/// Provides the processed history for a given tracker.
const int historyDays = 28;

final trackerOverviewProvider = StreamProvider.family<List<double>, String>((
  ref,
  trackerId,
) async* {
  final entryRepo = await ref.watch(entryRepositoryProvider.future);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(
    today.year,
    today.month,
    today.day - (historyDays - 1),
  );

  yield* entryRepo.watchEntriesInRange(trackerId, start, today).map((entries) {
    // Create map of all history days initialized to 0
    // Key is normalized DateTime (midnight)
    final dayMap = {
      for (int i = 0; i < historyDays; i++)
        DateTime(start.year, start.month, start.day + i): 0.0,
    };

    // Fill in tracked quantities
    for (final entry in entries) {
      final d = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (dayMap.containsKey(d)) {
        dayMap[d] = entry.quantity;
      }
    }

    // Convert to ordered list oldest → newest
    // Dart LinkedHashMaps preserve insertion order, so dayMap values are already correctly ordered from oldest to newest.
    return dayMap.values.toList();
  });
});
