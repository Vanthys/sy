import 'package:flutter_test/flutter_test.dart';
import 'package:sy/data/tracker_config.dart';

void main() {
  group('TrackerConfig', () {
    group('toJson / fromJson round-trip', () {
      test('preserves all fields', () {
        const config = TrackerConfig(
          maxValue: 100.0,
          inputType: InputType.slider,
          unit: 'km',
          intensityColors: ['#FF0000', '#00FF00'],
          streakColors: ['#0000FF', '#FFFF00'],
          options: ['a', 'b', 'c'],
          intensityGoal: 80.0,
          optionColors: ['#111111', '#222222', '#333333'],
        );

        final json = config.toJson();
        final restored = TrackerConfig.fromJson(json);

        expect(restored.maxValue, config.maxValue);
        expect(restored.inputType, config.inputType);
        expect(restored.unit, config.unit);
        expect(restored.intensityColors, config.intensityColors);
        expect(restored.streakColors, config.streakColors);
        expect(restored.options, config.options);
        expect(restored.intensityGoal, config.intensityGoal);
        expect(restored.optionColors, config.optionColors);
      });

      test('null fields survive round-trip', () {
        const config = TrackerConfig();
        final restored = TrackerConfig.fromJson(config.toJson());
        expect(restored.maxValue, isNull);
        expect(restored.unit, isNull);
        expect(restored.intensityColors, isNull);
        expect(restored.streakColors, isNull);
        expect(restored.options, isNull);
        expect(restored.optionColors, isNull);
        expect(restored.inputType, InputType.number);
      });
    });

    group('legacy migration', () {
      test('gradientColors → both intensityColors and streakColors', () {
        final json = {
          'gradientColors': ['#AAAAAA', '#BBBBBB'],
          'inputType': 'number',
        };
        final config = TrackerConfig.fromJson(json);
        expect(config.intensityColors, ['#AAAAAA', '#BBBBBB']);
        expect(config.streakColors, ['#AAAAAA', '#BBBBBB']);
      });

      test('streakColor (single string) → two-element list', () {
        final json = {'streakColor': '#123456', 'inputType': 'toggle'};
        final config = TrackerConfig.fromJson(json);
        expect(config.intensityColors, ['#123456', '#123456']);
        expect(config.streakColors, ['#123456', '#123456']);
      });

      test('explicit intensityColors/streakColors override legacy key', () {
        final json = {
          'gradientColors': ['#000000', '#111111'],
          'intensityColors': ['#FFFFFF'],
          'streakColors': ['#EEEEEE'],
          'inputType': 'number',
        };
        final config = TrackerConfig.fromJson(json);
        expect(config.intensityColors, ['#FFFFFF']);
        expect(config.streakColors, ['#EEEEEE']);
      });
    });

    group('unknown inputType', () {
      test('falls back to number', () {
        final json = {'inputType': 'nonexistent_type'};
        final config = TrackerConfig.fromJson(json);
        expect(config.inputType, InputType.number);
      });
    });

    group('equality and hashCode', () {
      test('equal configs are ==', () {
        const a = TrackerConfig(maxValue: 10.0, unit: 'reps');
        const b = TrackerConfig(maxValue: 10.0, unit: 'reps');
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different configs are not ==', () {
        const a = TrackerConfig(maxValue: 10.0);
        const b = TrackerConfig(maxValue: 20.0);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
