import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/prediction_result.dart';
import '../models/server_health.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic>? details;

  ApiException(this.message, {this.statusCode, this.code, this.details});

  @override
  String toString() => message;
}

class ValidationException extends ApiException {
  ValidationException(super.message, {super.code, super.details})
      : super(statusCode: 422);
}

/// Robust HTTP Client for Cotton Guard AI Server
class ApiService {
  final StorageService _storageService;
  final http.Client _client;

  ApiService(this._storageService, [http.Client? client])
      : _client = client ?? http.Client();

  String get _baseUrl {
    return ApiConstants.normalizeBaseUrl(_storageService.getServerUrl());
  }

  /// Evaluates server connectivity, model state, and measures latency
  Future<ServerHealth> checkHealth({String? overrideUrl}) async {
    final targetBase = (overrideUrl != null && overrideUrl.isNotEmpty)
        ? ApiConstants.normalizeBaseUrl(overrideUrl)
        : _baseUrl;

    final uri = Uri.parse('$targetBase${ApiConstants.endpointHealth}');
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client.get(uri).timeout(ApiConstants.connectTimeout);
      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return ServerHealth.fromJson(data, latencyMs: latency);
      } else {
        return ServerHealth(
          status: 'ERROR',
          version: 'N/A',
          uptimeSeconds: 0,
          modelLoaded: false,
          modelName: 'None',
          inferenceEngine: 'None',
          cottonValidationReady: false,
          diseaseModelReady: false,
          supportedClasses: [],
          timestamp: DateTime.now().toIso8601String(),
          latencyMs: latency,
          errorMessage: 'Server returned HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } on TimeoutException {
      return ServerHealth.disconnected(
        message: 'Connection timed out after ${ApiConstants.connectTimeout.inSeconds}s. Server is not responding.',
      );
    } on SocketException catch (e) {
      return ServerHealth.disconnected(
        message: 'Cannot establish connection to $targetBase (${e.message}). Check server status and IP.',
      );
    } catch (e) {
      return ServerHealth.disconnected(
        message: 'Network error: ${e.toString()}',
      );
    }
  }

  /// Uploads cotton leaf image for real AI disease inference
  Future<PredictionResult> predictDisease({
    required List<int> imageBytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointPredict}');

    try {
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: fileName,
        ),
      );

      final streamedResponse = await _client.send(request).timeout(ApiConstants.requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
        return PredictionResult.fromJson(data);
      } else if (response.statusCode == 422) {
        // Validation gate rejection (Poor Quality or Non-Cotton)
        try {
          final errJson = jsonDecode(response.body) as Map<String, dynamic>;
          final detail = errJson['detail'] as Map<String, dynamic>?;
          if (detail != null) {
            final code = detail['code'] as String? ?? 'VALIDATION_FAILED';
            final msg = detail['message'] as String? ?? 'Image failed validation.';
            final metrics = detail['metrics'] as Map<String, dynamic>?;
            throw ValidationException(msg, code: code, details: metrics);
          }
        } catch (e) {
          if (e is ValidationException) rethrow;
        }
        throw ValidationException(
          'Image was rejected by AI validation gate: ${response.body}',
          code: 'UNPROCESSABLE',
        );
      } else if (response.statusCode == 503) {
        throw ApiException(
          'Cotton Guard AI model is not ready on the server. Please check Server Connection status.',
          statusCode: 503,
          code: 'MODEL_NOT_READY',
        );
      } else {
        throw ApiException(
          'Server error (${response.statusCode}): ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      throw ApiException(
        'Inference request timed out after ${ApiConstants.requestTimeout.inSeconds} seconds. Check server responsiveness.',
        code: 'TIMEOUT',
      );
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot connect to Cotton Guard server at $_baseUrl (${e.message}).',
        code: 'CONNECTION_REFUSED',
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Unexpected network error: ${e.toString()}');
    }
  }

  /// Fetches comprehensive agronomic advisory library
  Future<Map<String, dynamic>> fetchAllAdvisories() async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAdvisoryAll}');
    try {
      final response = await _client.get(uri).timeout(ApiConstants.connectTimeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw ApiException('Failed to fetch advisories (HTTP ${response.statusCode})');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error loading advisory data: $e');
    }
  }

  /// Fetches agricultural regional and soil profiles
  Future<List<Map<String, dynamic>>> fetchFields() async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointFields}');
    try {
      final response = await _client.get(uri).timeout(ApiConstants.connectTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['regions'] as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ===========================================================================
  // AUTHENTICATION API METHODS
  // ===========================================================================

  /// Registers a new farmer account
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String fullName,
    String phone = '',
    String location = 'Warangal, Telangana',
    String role = 'Cotton Farmer',
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAuthRegister}');
    final payload = {
      'email': email.trim(),
      'password': password,
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'location': location.trim(),
      'role': role.trim(),
    };

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(ApiConstants.connectTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 || response.statusCode == 201) {
        return data;
      } else if (response.statusCode == 409) {
        throw ApiException(
          data['detail'] as String? ?? 'An account with this email already exists.',
          statusCode: 409,
          code: 'DUPLICATE_ACCOUNT',
        );
      } else {
        throw ApiException(
          data['detail'] as String? ?? 'Registration failed (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
          code: 'REGISTRATION_FAILED',
        );
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot connect to Cotton Guard server at $_baseUrl (${e.message}). Check server status and IP.',
        code: 'CONNECTION_REFUSED',
      );
    } on TimeoutException {
      throw ApiException(
        'Registration request timed out after ${ApiConstants.connectTimeout.inSeconds}s. Check server responsiveness.',
        code: 'TIMEOUT',
      );
    }
  }

  /// Authenticates with email and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAuthLogin}');
    final payload = {
      'email': email.trim(),
      'password': password,
    };

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(ApiConstants.connectTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      } else if (response.statusCode == 401) {
        throw ApiException(
          data['detail'] as String? ?? 'Invalid credentials. Please verify your email and password.',
          statusCode: 401,
          code: 'INVALID_CREDENTIALS',
        );
      } else {
        throw ApiException(
          data['detail'] as String? ?? 'Sign in failed (HTTP ${response.statusCode}).',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot connect to Cotton Guard server at $_baseUrl (${e.message}). Check server status and IP.',
        code: 'CONNECTION_REFUSED',
      );
    } on TimeoutException {
      throw ApiException(
        'Sign in request timed out after ${ApiConstants.connectTimeout.inSeconds}s. Check server responsiveness.',
        code: 'TIMEOUT',
      );
    }
  }

  /// Authenticates or links Google OAuth profile
  Future<Map<String, dynamic>> googleAuth({
    required String email,
    required String fullName,
    String? photoUrl,
    String idToken = '',
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAuthGoogle}');
    final payload = {
      'email': email.trim(),
      'full_name': fullName.trim(),
      'photo_url': photoUrl,
      'id_token': idToken,
    };

    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(ApiConstants.connectTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data;
      }
      throw ApiException(
        data['detail'] as String? ?? 'Google authentication failed on server.',
        statusCode: response.statusCode,
      );
    } on SocketException catch (e) {
      throw ApiException(
        'Cannot connect to Cotton Guard server at $_baseUrl (${e.message}). Check server status and IP.',
        code: 'CONNECTION_REFUSED',
      );
    } on TimeoutException {
      throw ApiException(
        'Google authentication timed out.',
        code: 'TIMEOUT',
      );
    }
  }

  /// Initiates password reset
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAuthForgotPassword}');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(ApiConstants.connectTimeout);

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Password reset request error: $e');
    }
  }

  /// Verifies token and resets password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAuthResetPassword}');
    try {
      final response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'reset_token': resetToken.trim(),
          'new_password': newPassword,
        }),
      ).timeout(ApiConstants.connectTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return data;
      throw ApiException(data['detail'] as String? ?? 'Password reset failed.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Password reset error: $e');
    }
  }

  // --- Administrator Control Plane Methods ---

  Map<String, String> _buildAdminHeaders({String? adminKey, String? token}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (adminKey != null && adminKey.trim().isNotEmpty) {
      headers['X-Admin-Key'] = adminKey.trim();
    }
    final activeToken = token ?? _storageService.getAuthToken();
    if (activeToken != null && activeToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $activeToken';
    }
    return headers;
  }

  /// Retrieves service state summary and recent audit logs
  Future<Map<String, dynamic>> getAdminServiceState({String? adminKey, String? token}) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAdminState}');
    try {
      final response = await _client.get(
        uri,
        headers: _buildAdminHeaders(adminKey: adminKey, token: token),
      ).timeout(ApiConstants.connectTimeout);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return data;
      throw ApiException(data['detail'] as String? ?? 'Failed to retrieve admin service state.', statusCode: response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching service state: $e');
    }
  }

  /// Administrative Start Service command
  Future<Map<String, dynamic>> startAdminService({String? adminKey, String? token}) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAdminStart}');
    try {
      final response = await _client.post(
        uri,
        headers: _buildAdminHeaders(adminKey: adminKey, token: token),
      ).timeout(ApiConstants.requestTimeout);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return data;
      throw ApiException(data['detail'] as String? ?? 'Failed to start AI service.', statusCode: response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error starting service: $e');
    }
  }

  /// Administrative Stop Service command
  Future<Map<String, dynamic>> stopAdminService({String? adminKey, String? token}) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAdminStop}');
    try {
      final response = await _client.post(
        uri,
        headers: _buildAdminHeaders(adminKey: adminKey, token: token),
      ).timeout(ApiConstants.requestTimeout);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return data;
      throw ApiException(data['detail'] as String? ?? 'Failed to stop AI service.', statusCode: response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error stopping service: $e');
    }
  }

  /// Retrieves service audit logs
  Future<List<dynamic>> getAdminServiceLogs({int limit = 50, String? adminKey, String? token}) async {
    final uri = Uri.parse('$_baseUrl${ApiConstants.endpointAdminLogs}?limit=$limit');
    try {
      final response = await _client.get(
        uri,
        headers: _buildAdminHeaders(adminKey: adminKey, token: token),
      ).timeout(ApiConstants.connectTimeout);
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return data['logs'] as List<dynamic>? ?? [];
      }
      throw ApiException(data['detail'] as String? ?? 'Failed to retrieve audit logs.', statusCode: response.statusCode);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error fetching service logs: $e');
    }
  }
}
