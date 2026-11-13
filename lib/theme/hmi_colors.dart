import 'package:flutter/material.dart';

/// Palette and layout constants from the official Shunting HMI Prototype.
class Hmi {
  Hmi._();

  static const Color bg = Color(0xFFF3F5F3);
  static const Color ink = Color(0xFF0F1F1B);
  static const Color muted = Color(0xFF4C5B57);
  static const Color card = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF0B7A61);
  static const Color accentSoft = Color(0xFFDCEFE9);
  static const Color red = Color(0xFFC62828);
  static const Color redDeep = Color(0xFF9F1717);
  static const Color off = Color(0xFFE4E9E6);
  static const Color hair = Color(0xFFD2DAD6);

  static BoxDecoration cardBox([double radius = 28]) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x170F1F1B),
            blurRadius: 14,
            offset: Offset(0, 2),
          ),
        ],
      );
}
