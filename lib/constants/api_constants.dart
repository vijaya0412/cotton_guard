/// Single source of truth for Cotton Guard API endpoints and configuration.
class ApiConstants {
  // Default base URL for Android Emulator & Cloud
  static const String defaultEmulatorUrl = "http://10.0.2.2:8000/api/v1";
  static const String defaultLocalhostUrl = "http://127.0.0.1:8000/api/v1";
  static const String defaultCloudUrl = "https://cotton-guard.onrender.com/api/v1";
  static const String defaultProductionUrl = defaultCloudUrl;

  /// Build-time configurable base URL with fallback to production Render URL.
  /// Override for local development via: --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
  static const String configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultCloudUrl,
  );

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

  // Timeouts (tuned for cloud cold starts and network latency on free-tier hosting)
  static const Duration connectTimeout = Duration(seconds: 45);
  static const Duration requestTimeout = Duration(seconds: 60);

  /// Helper to determine if a hostname/IP represents a local development environment.
  static bool _isLocalHost(String host) {
    final lower = host.toLowerCase();
    return lower == 'localhost' ||
        lower == '127.0.0.1' ||
        lower == '10.0.2.2' ||
        lower.startsWith('192.168.') ||
        lower.startsWith('10.') ||
        lower.endsWith('.local') ||
        RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(lower);
  }

  /// Robust URL Normalizer ensuring a valid HTTP/HTTPS endpoint root with /api/v1 suffix.
  /// Defaults un-schemed cloud domains (such as Hugging Face Spaces *.hf.space) to HTTPS,
  /// while preserving HTTP support for explicitly configured or inferred local development hosts.
  static String normalizeBaseUrl(String input) {
    String url = input.trim();
    if (url.isEmpty) return defaultProductionUrl;

    // Add protocol if missing: default cloud/public hosts to HTTPS, local hosts to HTTP
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      final host = url.split('/')[0].split(':')[0];
      if (_isLocalHost(host)) {
        url = 'http://$url';
      } else {
        url = 'https://$url';
      }
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
