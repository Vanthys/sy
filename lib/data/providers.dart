import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/data/database.dart';
import '/data/tracker_repository.dart';
import '/data/entry_repository.dart';
import '/logic/vault_provider.dart';

/// Provides the global AppDatabase instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  // Use a Provider to make the DB globally accessible
  // but we must initialize and dispose it properly.
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Provides the TrackerRepository.
final trackerRepositoryProvider = Provider<TrackerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final vault = ref.watch(vaultProvider);
  return TrackerRepository(db, vault);
});

/// Provides the EntryRepository.
final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return EntryRepository(db);
});

/// A provider that refreshes all streaks.
/// Passing true forces a full recalculation even if already done today.
final refreshStreaksProvider = FutureProvider.family<void, bool>((
  ref,
  force,
) async {
  final repo = ref.watch(entryRepositoryProvider);
  await repo.refreshAllStreaks(force: force);
});
