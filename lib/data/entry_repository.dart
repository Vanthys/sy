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
  // Normalize: strip time part
  final normalized = DateTime(date.year, date.month, date.day);
  final nextDay = normalized.add(const Duration(days: 1));

  // Try to find existing record for that date
  final existing = await (db.select(db.entries)
        ..where((e) => e.tracker.equals(trackerId))
        ..where((e) => e.date.isBetweenValues(normalized, nextDay)))
      .getSingleOrNull();

  if (amount > 0) {
    if (existing != null) {
      await (db.update(db.entries)..where((e) => e.id.equals(existing.id))).write(
        EntriesCompanion(
          quantity: Value(amount),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await db.into(db.entries).insert(
            EntriesCompanion(
              tracker: Value(trackerId),
              date: Value(normalized), // <— store as midnight
              quantity: Value(amount),
              createdAt: Value(DateTime.now()),
              updatedAt: Value(DateTime.now()),
            ),
          );
    }
  } else if (existing != null) {
    await (db.delete(db.entries)..where((e) => e.id.equals(existing.id))).go();
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

  Stream<List<Entry>> watchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) {
    // Extend 'to' by 1 day to make end inclusive
    final toInclusive = to.add(const Duration(days: 1));

    final query = (db.select(db.entries)
          ..where((e) => e.tracker.equals(trackerId))
          ..where((e) => e.date.isBetweenValues(from, toInclusive))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]));
    return query.watch();
  }

  Future<List<Entry>> fetchEntriesInRange(
    String trackerId,
    DateTime from,
    DateTime to,
  ) async {
    // Same fix for consistency
    final toInclusive = to.add(const Duration(days: 1));

    return (db.select(db.entries)
          ..where((e) => e.tracker.equals(trackerId))
          ..where((e) => e.date.isBetweenValues(from, toInclusive))
          ..orderBy([(e) => OrderingTerm.desc(e.date)]))
        .get();
  }
}
