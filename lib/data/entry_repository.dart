import 'package:drift/drift.dart';
import '/data/database.dart';

class EntryRepository {
  final AppDatabase db;

  EntryRepository(this.db);

  Future<List<Entry>> loadEntries(String trackerId) async {
    return (db.select(db.entries)
          ..where((e) => e.tracker.equals(trackerId))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .get();
  }


  Future<void> saveEntry(String trackerId, DateTime date, double amount) async {
    // Try to find an existing entry for the same tracker and calendar day
    final existing = await (db.select(db.entries)
          ..where((e) => e.tracker.equals(trackerId))
          ..where((e) => e.date.year.equals(date.year))
          ..where((e) => e.date.month.equals(date.month))
          ..where((e) => e.date.day.equals(date.day)))
        .getSingleOrNull();

    if (amount > 0) {
      if (existing != null) {
        await (db.update(db.entries)
              ..where((e) => e.id.equals(existing.id)))
            .write(
          EntriesCompanion(
            quantity: Value(amount),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } else {
        await db.into(db.entries).insert(
              EntriesCompanion(
                tracker: Value(trackerId),
                date: Value(date),
                quantity: Value(amount),
                createdAt: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
              ),
            );
      }
    } else if (existing != null) {
      await (db.delete(db.entries)
            ..where((e) => e.id.equals(existing.id)))
          .go();
    }
  }

  Stream<List<Entry>> watchEntries(String trackerId) {
  return (db.select(db.entries)
        ..where((e) => e.tracker.equals(trackerId))
        ..orderBy([(e) => OrderingTerm.desc(e.date)]))
      .watch();
  }


  Future<void> deleteEntry(int id) async {
    await (db.delete(db.entries)..where((e) => e.id.equals(id))).go();
  }
}
