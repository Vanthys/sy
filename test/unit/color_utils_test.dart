import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sy3/utils/color_utils.dart';

// Helper: compare Color by argb int value (avoids MaterialColor vs Color mismatch)
Matcher colorEquals(Color expected) => predicate<Color>(
  (c) => c.toARGB32() == expected.toARGB32(),
  'Color(0x${expected.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()})',
);

void main() {
  group('ColorUtils.parseHexColor', () {
    test('parses 6-char hex without #', () {
      final color = ColorUtils.parseHexColor('FF0000');
      expect(color?.toARGB32(), const Color(0xFFFF0000).toARGB32());
    });

    test('parses 6-char hex with #', () {
      final color = ColorUtils.parseHexColor('#00FF00');
      expect(color?.toARGB32(), const Color(0xFF00FF00).toARGB32());
    });

    test('parses 8-char AARRGGBB hex', () {
      final color = ColorUtils.parseHexColor('AABBCCDD');
      expect(color?.toARGB32(), const Color(0xAABBCCDD).toARGB32());
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
      expect(color.toARGB32(), Colors.grey.shade200.toARGB32());

      final colorNeg = ColorUtils.getColorForAmount(-5);
      expect(colorNeg.toARGB32(), Colors.grey.shade200.toARGB32());
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
      expect(color.toARGB32(), red.toARGB32());
    });

    test('amount >= maxValue clamps to last color', () {
      const blue = Color(0xFF0000FF);
      const green = Color(0xFF00FF00);
      final color = ColorUtils.getColorForAmount(
        100,
        preParsedColors: [blue, green],
        maxValue: 10,
      );
      expect(color.toARGB32(), green.toARGB32());
    });

    test('amount at exactly maxValue returns last color', () {
      const blue = Color(0xFF0000FF);
      const green = Color(0xFF00FF00);
      final color = ColorUtils.getColorForAmount(
        10,
        preParsedColors: [blue, green],
        maxValue: 10,
      );
      expect(color.toARGB32(), green.toARGB32());
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
      expect(color.toARGB32(), isNot(equals(blue.toARGB32())));
      expect(color.toARGB32(), isNot(equals(red.toARGB32())));
    });

    test('fallback when no colors provided — does not throw', () {
      expect(() => ColorUtils.getColorForAmount(3), returnsNormally);
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
      expect(color.toARGB32(), isNot(equals(blue.toARGB32())));
    });
  });

  group('ColorUtils.getColorForChoice', () {
    const optionColors = ['#FF0000', '#00FF00', '#0000FF'];

    test('valid index returns correct color', () {
      final color = ColorUtils.getColorForChoice(1, optionColors: optionColors);
      expect(color.toARGB32(), const Color(0xFF00FF00).toARGB32());
    });

    test('index 0 returns first color', () {
      final color = ColorUtils.getColorForChoice(0, optionColors: optionColors);
      expect(color.toARGB32(), const Color(0xFFFF0000).toARGB32());
    });

    test('negative index returns fallback', () {
      const fallback = Color(0xFFFF9800); // orange
      final color = ColorUtils.getColorForChoice(
        -1,
        optionColors: optionColors,
        fallback: fallback,
      );
      expect(color.toARGB32(), fallback.toARGB32());
    });

    test('index >= length returns fallback', () {
      const fallback = Color(0xFF9C27B0); // purple
      final color = ColorUtils.getColorForChoice(
        10,
        optionColors: optionColors,
        fallback: fallback,
      );
      expect(color.toARGB32(), fallback.toARGB32());
    });

    test('null optionColors returns fallback', () {
      const fallback = Color(0xFF009688); // teal
      final color = ColorUtils.getColorForChoice(
        0,
        optionColors: null,
        fallback: fallback,
      );
      expect(color.toARGB32(), fallback.toARGB32());
    });
  });
}
