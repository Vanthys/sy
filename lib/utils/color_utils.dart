import 'package:flutter/material.dart';

class ColorUtils {
  static Color getColorForAmount(
    double amount, {
    List<String>? gradientColors,
    double? maxValue,
  }) {
    if (amount <= 0) return Colors.grey.shade200;

    List<Color> colors;
    if (gradientColors == null || gradientColors.isEmpty) {
      colors = [const Color(0xFF2196F3), const Color(0xFF2196F3)]; // fallback
    } else {
      colors = gradientColors.map(parseHexColor).whereType<Color>().toList();
      if (colors.isEmpty) {
        colors = [const Color(0xFF2196F3), const Color(0xFF2196F3)];
      }
      if (colors.length == 1) {
        colors.add(colors.first);
      }
    }

    final ratio = (amount / (maxValue ?? 15.0)).clamp(0.0, 1.0);

    final segment = 1.0 / (colors.length - 1);
    final index = (ratio / segment).floor().clamp(0, colors.length - 2);
    final localRatio = ((ratio - (index * segment)) / segment).clamp(0.0, 1.0);

    return Color.lerp(colors[index], colors[index + 1], localRatio) ??
        colors.last;
  }

  static Color? parseHexColor(String? hexString) {
    if (hexString == null) return null;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    try {
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return null;
    }
  }
}
