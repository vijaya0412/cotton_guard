import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/api_constants.dart';

class GoogleAuthException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final bool isConfigurationError;

  GoogleAuthException(
    this.message, {
    this.code,
    this.statusCode,
    this.isConfigurationError = false,
  });

  @override
  String toString() => message;
}

/// Service providing real Google Sign-In via Google Play Services / OAuth.
class GoogleAuthService {
  final GoogleSignIn _googleSignIn;

  GoogleAuthService([GoogleSignIn? googleSignIn, String? serverClientId])
      : _googleSignIn = googleSignIn ??
            GoogleSignIn(
              serverClientId: serverClientId ?? ApiConstants.googleServerClientId,
              scopes: const <String>[],
            );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Safely extracts numeric Google Play Services status code from PlatformException.
  static int? extractStatusCode(PlatformException e) {
    final direct = int.tryParse(e.code);
    if (direct != null) return direct;

    final msg = e.message ?? '';

    // 1. Matches "ApiException: 10", "ql: 10", "abc: 12500", "status: 10", "code: 10", etc.
    final match = RegExp(r'(?:[a-zA-Z0-9_$.]+)\s*[:=]\s*(\d+)').firstMatch(msg);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    // 2. Matches known Google Play Services error codes
    final knownMatch = RegExp(r'\b(10|12500|12501|12502|7|8|4|5|13|16)\b').firstMatch(msg);
    if (knownMatch != null) {
      return int.tryParse(knownMatch.group(1)!);
    }

    // 3. Any standalone integer
    final numMatch = RegExp(r'\b(\d{1,5})\b').firstMatch(msg);
    if (numMatch != null) {
      return int.tryParse(numMatch.group(1)!);
    }

    return null;
  }

  /// Triggers genuine Google Account selection flow
  Future<GoogleSignInAccount?> signIn() async {
    try {
      debugPrint('[GoogleAuth] Initiating Google Play Services sign-in dialog...');
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('[GoogleAuth] User dismissed or cancelled the Google account picker.');
      } else {
        debugPrint('[GoogleAuth] Google account selected: ${account.email}');
      }
      return account;
    } on PlatformException catch (e) {
      debugPrint('[GoogleAuth] PlatformException: code="${e.code}", message="${e.message}", details="${e.details}"');

      // User cancellation
      if (e.code == 'sign_in_canceled' ||
          e.code == '12501' ||
          e.message?.contains('12501') == true ||
          e.message?.toLowerCase().contains('canceled') == true) {
        debugPrint('[GoogleAuth] Account selection cancelled by user.');
        return null;
      }

      final statusCode = extractStatusCode(e);
      debugPrint('[GoogleAuth] Resolved Play Services status code: $statusCode');

      // DEVELOPER_ERROR (10)
      if (statusCode == 10 ||
          e.code == '10' ||
          e.message?.contains('DEVELOPER_ERROR') == true ||
          e.message?.contains(': 10') == true) {
        throw GoogleAuthException(
          'Google Sign-In DEVELOPER_ERROR (10): Google Play Services rejected the request.\n'
          'Root Cause: In Google Cloud Console, your Android OAuth client must belong to the SAME project as the Web client (#647603326934).\n'
          'Resolution:\n'
          '1. In Google Cloud Console, select project 647603326934.\n'
          '2. In APIs & Services -> Credentials, verify an Android OAuth client exists with package "com.cottonguard.app.cottonguard" and SHA-1 "4E:97:C3:84:CF:BD:0D:13:2B:81:EC:7A:1D:E1:DA:7C:23:8D:64:8B".\n'
          '3. In OAuth Consent Screen, ensure User Support Email is selected and saved.\n'
          '4. On your phone, clear Google Play Services cache (Settings -> Apps -> Google Play Services -> Storage -> Clear Cache).',
          code: '10',
          statusCode: 10,
          isConfigurationError: true,
        );
      }

      // SIGN_IN_FAILED (12500)
      if (statusCode == 12500 || e.code == '12500') {
        throw GoogleAuthException(
          'Google Sign-In failed [SIGN_IN_FAILED (12500)]: '
          'When Google OAuth Consent Screen is in "Testing" status, your Google account must be explicitly added '
          'under "Audience -> Test users" in Google Cloud Console. Also verify that the OAuth Consent Screen has a valid User Support Email.',
          code: '12500',
          statusCode: 12500,
          isConfigurationError: true,
        );
      }

      // NETWORK_ERROR (7)
      if (statusCode == 7 || e.code == 'network_error' || e.code == '7') {
        throw GoogleAuthException(
          'Google Sign-In network error (code 7): Unable to reach Google authentication servers. Please verify your internet connection.',
          code: '7',
          statusCode: 7,
        );
      }

      // INTERNAL_ERROR (8)
      if (statusCode == 8 || e.code == '8') {
        throw GoogleAuthException(
          'Google Sign-In internal error (code 8): Google Play Services internal issue. Please try restarting Google Play Services or the device.',
          code: '8',
          statusCode: 8,
        );
      }

      // General fallback with exact codes
      final codeDisplay = statusCode != null ? 'status $statusCode' : 'code "${e.code}"';
      throw GoogleAuthException(
        'Google authentication failed ($codeDisplay): ${e.message ?? 'Unknown error'}',
        code: e.code,
        statusCode: statusCode,
      );
    } catch (e) {
      if (e is GoogleAuthException) rethrow;
      debugPrint('[GoogleAuth] Unexpected exception during signIn: $e');
      throw GoogleAuthException('Unexpected Google Sign-In error: $e');
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[GoogleAuth] Error during signOut: $e');
    }
  }
}
