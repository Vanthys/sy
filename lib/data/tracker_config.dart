import 'package:flutter/foundation.dart';

enum InputType { number, toggle, choice, slider, timer, text }

class TrackerConfig {
  final double? maxValue;
  final InputType inputType;
  final String? unit;
  final List<String>? intensityColors;
  final List<String>? streakColors;
  final List<String>? options;
  final double? intensityGoal;
  final List<String>? optionColors;

  const TrackerConfig({
    this.maxValue,
    this.inputType = InputType.number,
    this.unit,
    this.intensityColors,
    this.streakColors,
    this.options,
    this.intensityGoal,
    this.optionColors,
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

    List<String>? parsedOptions;
    if (json['options'] != null) {
      parsedOptions = (json['options'] as List)
          .map((e) => e.toString())
          .toList();
    }

    List<String>? parsedOptionColors;
    if (json['optionColors'] != null) {
      parsedOptionColors = (json['optionColors'] as List)
          .map((e) => e.toString())
          .toList();
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
      options: parsedOptions,
      intensityGoal: (json['intensityGoal'] as num?)?.toDouble(),
      optionColors: parsedOptionColors,
    );
  }

  Map<String, dynamic> toJson() => {
    'maxValue': maxValue,
    'inputType': inputType.name,
    'unit': unit,
    'intensityColors': intensityColors,
    'streakColors': streakColors,
    'options': options,
    'intensityGoal': intensityGoal,
    'optionColors': optionColors,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackerConfig &&
          runtimeType == other.runtimeType &&
          maxValue == other.maxValue &&
          inputType == other.inputType &&
          unit == other.unit &&
          intensityGoal == other.intensityGoal &&
          listEquals(intensityColors, other.intensityColors) &&
          listEquals(streakColors, other.streakColors) &&
          listEquals(options, other.options) &&
          listEquals(optionColors, other.optionColors);

  @override
  int get hashCode => Object.hash(
        maxValue,
        inputType,
        unit,
        intensityGoal,
        Object.hashAll(intensityColors ?? []),
        Object.hashAll(streakColors ?? []),
        Object.hashAll(options ?? []),
        Object.hashAll(optionColors ?? []),
      );
}
