import 'package:flutter/material.dart';

/// Typography hierarchy for Cotton Guard
class AppTypography {
  static const String fontFamily = 'Roboto';

  static TextStyle display(Color color) => TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle headline(Color color) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle titleLarge(Color color) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle titleMedium(Color color) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle bodyLarge(Color color) => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle bodyMedium(Color color) => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle bodySmall(Color color) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle label(Color color, {bool isBold = false}) => TextStyle(
        fontSize: 12,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
        letterSpacing: 0.2,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle editorial(Color color) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.25,
        color: color,
        fontFamily: fontFamily,
      );

  static TextStyle caption(Color color) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: color,
        fontFamily: fontFamily,
      );
}
