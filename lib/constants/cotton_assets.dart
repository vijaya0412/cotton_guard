import 'canonical_classes.dart';

/// Centralized photography and asset management for Cotton Guard.
/// Provides authentic cotton field and leaf imagery for UI components.
class CottonAssets {
  CottonAssets._();

  // Branding & Hero Photography
  static const String logo = 'assets/images/cotton_guard_logo.png';
  static const String splash = 'assets/images/cotton_field_splash.jpg';
  static const String onboardingHero = 'assets/images/cotton_leaf_hero.jpg';

  // Disease assets mapping by class name
  static String getPrimaryDiseaseImage(String className) {
    return CanonicalClasses.getPrimaryAssetImage(className);
  }

  static List<String> getDiseaseGallery(String className) {
    return CanonicalClasses.getSampleAssetImages(className);
  }

  // Representative authentic images for features
  static const String scanCardHero = 'assets/diseases/healthy_leaf/healthy_leaf_1.jpg';
  static const String diseaseLibraryHero = 'assets/diseases/bacterial_blight/bacterial_blight_1.jpg';
  static const String insightsHero = 'assets/diseases/curl_virus/curl_virus_1.jpg';
  static const String advisoryHero = 'assets/diseases/leaf_hopper_jassids/leaf_hopper_jassids_1.jpg';

  // Safe fallback
  static String safeImage(String? path) {
    if (path == null || path.isEmpty) return logo;
    return path;
  }
}
