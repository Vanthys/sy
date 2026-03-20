import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy3/utils/color_utils.dart';

// Helper: compare Color by argb int value (avoids MaterialColor vs Color mismatch)
Matcher colorEquals(Color expected) =>
    predicate<Color>((c) => c.value == expected.value, 'Color(0x${expected.value.toRadixString(16).padLeft(8, '0').toUpperCase()})');

void main() {
  group('ColorUtils.parseHexColor', () {
    test('parses 6-char hex without #', () {
      final color = ColorUtils.parseHexColor('FF0000');
      expect(color?.value, const Color(0xFFFF0000).value);
    });

    test('parses 6-char hex with #', () {
      final color = ColorUtils.parseHexColor('#00FF00');
      expect(color?.value, const Color(0xFF00FF00).value);
    });

    test('parses 8-char AARRGGBB hex', () {
      final color = ColorUtils.parseHexColor('AABBCCDD');
      expect(color?.value, const Color(0xAABBCCDD).value);
    });

    test('returns null for null input', () {
      expect(ColorUtils.parseHexColor(null), isNull);
    });

    test('returns null for non-hex string', () {
      expect(ColorUtils.parseHexColor('ZZZZZZ'), isNull);
    });
  });

  group('ColorUtils.getColorForAmount', () {
    test('amount <= 0 returns grey.shade200', () {
      final color = ColorUtils.getColorForAmount(0);
      expect(color.value, Colors.grey.shade200.value);

      final colorNeg = ColorUtils.getColorForAmount(-5);
      expect(colorNeg.value, Colors.grey.shade200.value);
    });

    test('single color list → always returns that color', () {
      // A single entry is duplicated to [red, red] internally,
      // so lerp always returns red regardless of the ratio.
      const red = Color(0xFFFF0000);
      final color = ColorUtils.getColorForAmount(
        5,
        preParsedColors: [red],
        maxValue: 10,
      );
      expect(color.value, red.value);
    });

    test('amount >= maxValue clamps to last color', () {
      const blue = Color(0xFF0000FF);
      const green = Color(0xFF00FF00);
      final color = ColorUtils.getColorForAmount(
        100,
        preParsedColors: [blue, green],
        maxValue: 10,
      );
      expect(color.value, green.value);
    });

    test('amount at exactly maxValue returns last color', () {
      const blue = Color(0xFF0000FF);
      const green = Color(0xFF00FF00);
      final color = ColorUtils.getColorForAmount(
        10,
        preParsedColors: [blue, green],
        maxValue: 10,
      );
      expect(color.value, green.value);
    });

    test('mid-range interpolates between two colors', () {
      // At exactly 50% we should get a blend between blue and red
      const blue = Color(0xFF0000FF);
      const red = Color(0xFFFF0000);
      final color = ColorUtils.getColorForAmount(
        5,
        preParsedColors: [blue, red],
        maxValue: 10,
      );
      // Not blue, not red, but somewhere in between
      expect(color.value, isNot(equals(blue.value)));
      expect(color.value, isNot(equals(red.value)));
    });

    test('fallback when no colors provided — does not throw', () {
      expect(
        () => ColorUtils.getColorForAmount(3),
        returnsNormally,
      );
    });

    test('three-color gradient picks correct segment at 90%', () {
      const blue = Color(0xFF0000FF);
      const yellow = Color(0xFFFFFF00);
      const red = Color(0xFFFF0000);
      final color = ColorUtils.getColorForAmount(
        9, // 90% → second segment (yellow→red)
        preParsedColors: [blue, yellow, red],
        maxValue: 10,
      );
      // Not blue
      expect(color.value, isNot(equals(blue.value)));
    });
  });

  group('ColorUtils.getColorForChoice', () {
    const optionColors = ['#FF0000', '#00FF00', '#0000FF'];

    test('valid index returns correct color', () {
      final color = ColorUtils.getColorForChoice(1, optionColors: optionColors);
      expect(color.value, const Color(0xFF00FF00).value);
    });

    test('index 0 returns first color', () {
      final color = ColorUtils.getColorForChoice(0, optionColors: optionColors);
      expect(color.value, const Color(0xFFFF0000).value);
    });

    test('negative index returns fallback', () {
      const fallback = Color(0xFFFF9800); // orange
      final color = ColorUtils.getColorForChoice(
        -1,
        optionColors: optionColors,
        fallback: fallback,
      );
      expect(color.value, fallback.value);
    });

    test('index >= length returns fallback', () {
      const fallback = Color(0xFF9C27B0); // purple
      final color = ColorUtils.getColorForChoice(
        10,
        optionColors: optionColors,
        fallback: fallback,
      );
      expect(color.value, fallback.value);
    });

    test('null optionColors returns fallback', () {
      const fallback = Color(0xFF009688); // teal
      final color = ColorUtils.getColorForChoice(
        0,
        optionColors: null,
        fallback: fallback,
      );
      expect(color.value, fallback.value);
    });
  });
}
