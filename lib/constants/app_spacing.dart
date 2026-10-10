import 'package:flutter/material.dart';

/// Centralized layout tokens: Spacing, Border Radii, and Elevation for Cotton Guard.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 40.0;
}

class AppRadius {
  AppRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double pill = 999.0;

  static BorderRadius get smBorder => BorderRadius.circular(sm);
  static BorderRadius get mdBorder => BorderRadius.circular(md);
  static BorderRadius get lgBorder => BorderRadius.circular(lg);
  static BorderRadius get xlBorder => BorderRadius.circular(xl);
  static BorderRadius get xxlBorder => BorderRadius.circular(xxl);
  static BorderRadius get pillBorder => BorderRadius.circular(pill);
}

class AppElevation {
  AppElevation._();

  static List<BoxShadow> lightCard = [
    BoxShadow(
      color: Colors.black.withAlpha(10),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> floating = [
    BoxShadow(
      color: const Color(0xFF1B4D3E).withAlpha(45),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> darkCard = [];
}
