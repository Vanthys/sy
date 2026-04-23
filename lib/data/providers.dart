import 'package:isar_community/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '/data/database.dart';
import '/data/entry_repository.dart';
import '/data/tracker_repository.dart';
import '/logic/vault_provider.dart';
import '/services/database_service.dart';
import '/services/shared_preferences_provider.dart';

part 'providers.g.dart';

@Riverpod(keepAlive: true)
Future<Isar> isar(Ref ref) async {
  final database = ref.watch(databaseServiceProvider);
  return database.open();
}

@Riverpod(keepAlive: true)
Future<TrackerRepository> trackerRepository(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  final access = ref.watch(vaultAccessProvider);
  return TrackerRepository(isar, access);
}

@Riverpod(keepAlive: true)
Future<EntryRepository> entryRepository(Ref ref) async {
  final isar = await ref.watch(isarProvider.future);
  final prefs = ref.watch(sharedPreferencesProvider);
  return EntryRepository(isar, prefs);
}

@Riverpod(keepAlive: true)
Stream<List<Tracker>> trackerList(Ref ref) async* {
  final repo = await ref.watch(trackerRepositoryProvider.future);
  yield* repo.watchAllTrackers();
}

@Riverpod(keepAlive: true)
Future<void> refreshStreaks(Ref ref, bool force) async {
  final repo = await ref.watch(entryRepositoryProvider.future);
  await repo.refreshAllStreaks(force: force);
}
