import 'package:isar_community/isar.dart';

part 'entry_schema.g.dart';

@collection
class IsarEntry {
  Id? id;

  /// UUID of the parent [IsarTracker]
  @Index()
  late String trackerId;

  /// Midnight-normalised date of the entry
  @Index()
  late DateTime date;

  late double quantity;
  String? comment;

  late DateTime createdAt;
  late DateTime updatedAt;
}
