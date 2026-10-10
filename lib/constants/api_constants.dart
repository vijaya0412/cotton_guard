/// Single source of truth for Cotton Guard API endpoints and configuration.
class ApiConstants {
  // Default base URL for Android Emulator & Cloud
  static const String defaultEmulatorUrl = "http://10.0.2.2:8000/api/v1";
  static const String defaultLocalhostUrl = "http://127.0.0.1:8000/api/v1";
  static const String defaultCloudUrl = "https://api.cottonguard.org/api/v1";

  // Endpoints
  static const String endpointHealth = "/health";
  static const String endpointPredict = "/predict";
  static const String endpointAdvisoryAll = "/advisory/all";
  static const String endpointFields = "/fields";
  static const String endpointDiseaseDetail = "/disease";
  static const String endpointAuthRegister = "/auth/register";
  static const String endpointAuthLogin = "/auth/login";
  static const String endpointAuthGoogle = "/auth/google";
  static const String endpointAuthMe = "/auth/me";
  static const String endpointAuthForgotPassword = "/auth/forgot-password";
  static const String endpointAuthResetPassword = "/auth/reset-password";

  // Admin Control Endpoints
  static const String endpointAdminState = "/admin/service/state";
  static const String endpointAdminStart = "/admin/service/start";
  static const String endpointAdminStop = "/admin/service/stop";
  static const String endpointAdminLogs = "/admin/service/logs";

  // Google OAuth Web Application Client ID
  // Required on Android as serverClientId so Google Play Services returns an idToken for backend verification.
  static const String googleServerClientId =
      "647603326934-slkp7nf3ftducsfjq1dscvs06kj0q4im.apps.googleusercontent.com";

  // Timeouts (tuned for cloud cold starts and network latency)
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration requestTimeout = Duration(seconds: 45);


  /// Robust URL Normalizer ensuring a valid HTTP/HTTPS endpoint root with /api/v1 suffix.
  static String normalizeBaseUrl(String input) {
    String url = input.trim();
    if (url.isEmpty) return defaultEmulatorUrl;

    // Add protocol if missing
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    // Strip trailing slashes
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    // Ensure /api/v1 is present
    if (!url.endsWith('/api/v1')) {
      if (url.endsWith('/api')) {
        url = '$url/v1';
      } else {
        url = '$url/api/v1';
      }
    }

    return url;
  }
}
