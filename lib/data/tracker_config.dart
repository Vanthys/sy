import 'dart:convert';
import 'package:drift/drift.dart';

enum InputType { number, slider, toggle, timer, text }

class TrackerConfig {
  final double? maxValue;
  final InputType inputType;
  final String? unit;
  final String? streakColor;

  const TrackerConfig({
    this.maxValue,
    this.inputType = InputType.number,
    this.unit,
    this.streakColor,
  });

  factory TrackerConfig.fromJson(Map<String, dynamic> json) => TrackerConfig(
        maxValue: (json['maxValue'] as num?)?.toDouble(),
        inputType: InputType.values.firstWhere(
          (e) => e.name == json['inputType'],
          orElse: () => InputType.number,
        ),
        unit: json['unit'] as String?,
        streakColor: json['streakColor'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'maxValue': maxValue,
        'inputType': inputType.name,
        'unit': unit,
        'streakColor': streakColor,
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
