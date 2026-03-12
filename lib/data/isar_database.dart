import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';
import '/data/schemas/tracker_schema.dart';
import '/data/schemas/entry_schema.dart';

/// Opens and returns a global [Isar] instance.
/// This is the single source of truth for the app's local database.
Future<Isar> openIsarDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  return Isar.open([IsarTrackerSchema, IsarEntrySchema], directory: dir.path);
}
