import 'dart:convert';
import 'package:drift/drift.dart';

enum InputType { number, slider, toggle, timer, text }

class TrackerConfig {
  final double? maxValue;
  final InputType inputType;
  final String? unit;
  final List<String>? intensityColors;
  final List<String>? streakColors;

  const TrackerConfig({
    this.maxValue,
    this.inputType = InputType.number,
    this.unit,
    this.intensityColors,
    this.streakColors,
  });

  factory TrackerConfig.fromJson(Map<String, dynamic> json) {
    // Legacy migrations
    List<String>? legacyGradients;
    if (json['gradientColors'] != null) {
      legacyGradients = (json['gradientColors'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (json['streakColor'] != null) {
      final legacyColor = json['streakColor'] as String;
      legacyGradients = [legacyColor, legacyColor];
    }

    List<String>? parsedIntensity;
    if (json['intensityColors'] != null) {
      parsedIntensity = (json['intensityColors'] as List)
          .map((e) => e.toString())
          .toList();
    } else {
      parsedIntensity = legacyGradients;
    }

    List<String>? parsedStreak;
    if (json['streakColors'] != null) {
      parsedStreak = (json['streakColors'] as List)
          .map((e) => e.toString())
          .toList();
    } else {
      parsedStreak = legacyGradients;
    }

    return TrackerConfig(
      maxValue: (json['maxValue'] as num?)?.toDouble(),
      inputType: InputType.values.firstWhere(
        (e) => e.name == json['inputType'],
        orElse: () => InputType.number,
      ),
      unit: json['unit'] as String?,
      intensityColors: parsedIntensity,
      streakColors: parsedStreak,
    );
  }

  Map<String, dynamic> toJson() => {
    'maxValue': maxValue,
    'inputType': inputType.name,
    'unit': unit,
    'intensityColors': intensityColors,
    'streakColors': streakColors,
  };
}

class TrackerConfigConverter extends TypeConverter<TrackerConfig, String> {
  const TrackerConfigConverter();

  @override
  TrackerConfig fromSql(String fromDb) =>
      TrackerConfig.fromJson(jsonDecode(fromDb));

  @override
  String toSql(TrackerConfig value) => jsonEncode(value.toJson());
}
