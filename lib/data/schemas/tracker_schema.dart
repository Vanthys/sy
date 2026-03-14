import 'package:isar_community/isar.dart';

part 'tracker_schema.g.dart';

@collection
class IsarTracker {
  Id? id;

  @Index(unique: true)
  late String uuid;

  late String title;
  String? description;

  /// Stored as the integer index of [StreakType]
  late int streakTypeIndex;

  /// Stored as the integer index of [PrivacyLevel]
  late int privacyLevelIndex;

  /// TrackerConfig serialised as JSON (same format as before)
  late String configJson;

  late int currentStreak;
  late int longestStreak;

  late DateTime createdAt;
  late DateTime updatedAt;

  @Index()
  late int sortOrder;
}
