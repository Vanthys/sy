// data/database.dart
// Pure Dart data classes replacing the Drift-generated database schema.
// Value<T> is provided locally to preserve the existing copyWith API in tracker_repository.dart.

import '/data/tracker_config.dart';

// ---------------------------------------------------------------------------
// Value<T> — minimal shim to replace the Drift Value type used in copyWith
// ---------------------------------------------------------------------------

class Value<T> {
  final T value;
  const Value(this.value);
  static Value<T?> absentIfNull<T>(T? val) => Value(val);
  static const Value<Object?> absent = Value(null);
}

// ---------------------------------------------------------------------------
// Enums (unchanged)
// ---------------------------------------------------------------------------

enum StreakType { continued, abstinence }

enum PrivacyLevel { standard, vault, secret }

// ---------------------------------------------------------------------------
// Tracker — replaces the Drift-generated data class
// ---------------------------------------------------------------------------

class Tracker {
  final String id;
  final String title;
  final String? description;
  final StreakType streakType;
  final PrivacyLevel privacyLevel;
  final TrackerConfig config;
  final int currentStreak;
  final int longestStreak;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int sortOrder;

  const Tracker({
    required this.id,
    required this.title,
    this.description,
    required this.streakType,
    this.privacyLevel = PrivacyLevel.standard,
    required this.config,
    this.currentStreak = 0,
    this.longestStreak = 0,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  Tracker copyWith({
    String? id,
    String? title,
    Value<String?>? description,
    StreakType? streakType,
    PrivacyLevel? privacyLevel,
    TrackerConfig? config,
    int? currentStreak,
    int? longestStreak,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return Tracker(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description != null ? description.value : this.description,
      streakType: streakType ?? this.streakType,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      config: config ?? this.config,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

// ---------------------------------------------------------------------------
// Entry — replaces the Drift-generated data class
// ---------------------------------------------------------------------------

class Entry {
  final int id;
  final String tracker; // trackerId UUID
  final DateTime date;
  final double quantity;
  final String? comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Entry({
    required this.id,
    required this.tracker,
    required this.date,
    required this.quantity,
    this.comment,
    required this.createdAt,
    required this.updatedAt,
  });
}
