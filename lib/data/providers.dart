import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import '/data/isar_database.dart';
import '/data/tracker_repository.dart';
import '/data/entry_repository.dart';
import '/logic/vault_provider.dart';

// ---------------------------------------------------------------------------
// Isar instance — async, opened once at startup.
// ---------------------------------------------------------------------------

final isarProvider = FutureProvider<Isar>((ref) async {
  final isar = await openIsarDatabase();
  return isar;
});

// ---------------------------------------------------------------------------
// Repositories — async because they depend on Isar.
// ---------------------------------------------------------------------------

final trackerRepositoryProvider = FutureProvider<TrackerRepository>((
  ref,
) async {
  final isar = await ref.watch(isarProvider.future);

  // Watch only the fields that affect repository data access and encryption
  ref.watch(vaultProvider.select((s) => (s.unlockedLevel, s.activeKey)));

  // Read the full state object to pass into the repository
  final vault = ref.read(vaultProvider);

  return TrackerRepository(isar, vault);
});

final entryRepositoryProvider = FutureProvider<EntryRepository>((ref) async {
  final isar = await ref.watch(isarProvider.future);
  return EntryRepository(isar);
});

// ---------------------------------------------------------------------------
// Convenience: typed tracker list stream — drives the main list screen.
// ---------------------------------------------------------------------------

final trackerListProvider = StreamProvider((ref) async* {
  final repo = await ref.watch(trackerRepositoryProvider.future);
  yield* repo.watchAllTrackers();
});

// ---------------------------------------------------------------------------
// Streak refresh
// ---------------------------------------------------------------------------

final refreshStreaksProvider = FutureProvider.family<void, bool>((
  ref,
  force,
) async {
  final repo = await ref.watch(entryRepositoryProvider.future);
  await repo.refreshAllStreaks(force: force);
});
