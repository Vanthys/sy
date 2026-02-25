import 'package:flutter/material.dart';

class ColorUtils {
  static Color getColorForAmount(double amount) {
    if (amount <= 0) return Colors.grey.shade200;

    final ratio = (amount / 15).clamp(0.0, 1.0);

    final r = (63 + (252 - 63) * ratio).round();
    final g = (94 + (70 - 94) * ratio).round();
    final b = (251 + (107 - 251) * ratio).round();

    return Color.fromRGBO(r, g, b, 1);
  }

  static Color? parseHexColor(String? hexString) {
    if (hexString == null) return null;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
