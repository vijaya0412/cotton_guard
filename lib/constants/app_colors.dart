import 'package:flutter/material.dart';

/// Premium Agricultural Design System Colors for Cotton Guard
class AppColors {
  // Light Theme Palette
  static const Color primary = Color(0xFF1B4D3E); // Deep Forest Evergreen
  static const Color primaryLight = Color(0xFF2E7D32); // Fresh Foliage Green
  static const Color primaryDark = Color(0xFF0F3127); // Dark Pine Green
  static const Color secondary = Color(0xFF81C784); // Soft Leaf Green
  static const Color accent = Color(0xFFD97706); // Warm Earthy Amber / Cotton Boll accent
  static const Color accentLight = Color(0xFFFDE68A); // Pale Honey

  static const Color backgroundLight = Color(0xFFF7FAF7); // Warm Clean Off-White
  static const Color surfaceLight = Color(0xFFFFFFFF); // Pure White Surface
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  static const Color textPrimaryLight = Color(0xFF1A201C); // Deep Charcoal
  static const Color textSecondaryLight = Color(0xFF4A5568); // Muted Slate
  static const Color textMutedLight = Color(0xFF718096);

  // Dark Theme Palette
  static const Color backgroundDark = Color(0xFF101713); // Deep Soil Dark
  static const Color surfaceDark = Color(0xFF17221C); // Dark Forest Slate
  static const Color cardDark = Color(0xFF1E2C24); // Elevated Dark Card
  static const Color borderDark = Color(0xFF283B31);

  static const Color textPrimaryDark = Color(0xFFF1F5F2); // Crisp Off-White
  static const Color textSecondaryDark = Color(0xFFA0AEC0); // Soft Grey
  static const Color textMutedDark = Color(0xFF718096);

  // Status & Severity Indicators
  static const Color success = Color(0xFF2E7D32); // Healthy green
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFD97706); // Moderate severity amber
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626); // High severity red
  static const Color dangerLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB); // Information blue
  static const Color infoLight = Color(0xFFEFF6FF);

  // AI & Scanning Accents
  static const Color scanBeam = Color(0xFF4ADE80); // Electric Leaf Green Beam
  static const Color scanGlow = Color(0x334ADE80);

  // Theme-Aware Dynamic Helpers
  static Color background(bool isDark) => isDark ? backgroundDark : backgroundLight;
  static Color surface(bool isDark) => isDark ? surfaceDark : surfaceLight;
  static Color card(bool isDark) => isDark ? cardDark : cardLight;
  static Color border(bool isDark) => isDark ? borderDark : borderLight;
  static Color textPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(bool isDark) => isDark ? textSecondaryDark : textSecondaryLight;
  static Color textMuted(bool isDark) => isDark ? textMutedDark : textMutedLight;
  static Color primaryAction(bool isDark) => isDark ? secondary : primary;
}
