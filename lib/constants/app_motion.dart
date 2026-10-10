import 'package:flutter/material.dart';

/// Centralized motion design tokens for Cotton Guard.
class AppMotion {
  AppMotion._();

  // Durations
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration medium = Duration(milliseconds: 380);
  static const Duration slow = Duration(milliseconds: 650);
  static const Duration entrance = Duration(milliseconds: 800);

  // Animation Curves
  static const Curve curveDefault = Curves.easeInOutCubic;
  static const Curve curveEnter = Curves.easeOutCubic;
  static const Curve curveExit = Curves.easeInCubic;
  static const Curve curveEmphasized = Curves.fastOutSlowIn;
}
