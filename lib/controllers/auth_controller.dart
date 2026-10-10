import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import '../constants/api_constants.dart';

/// Real Authentication, Session, and User Profile Controller.
class AuthController extends ChangeNotifier {
  final StorageService _storageService;
  final ApiService _apiService;
  final GoogleAuthService _googleAuthService;

  UserProfile? _currentUser;
  bool _isLoggedIn = false;
  bool _isGuest = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthController(
    this._storageService, [
    ApiService? apiService,
    GoogleAuthService? googleAuthService,
  ])  : _apiService = apiService ?? ApiService(_storageService),
        _googleAuthService = googleAuthService ?? GoogleAuthService() {
    _loadSession();
  }

  UserProfile? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isGuest => _isGuest;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _loadSession() {
    _isLoggedIn = _storageService.isLoggedIn();
    _isGuest = _storageService.isGuest();
    _currentUser = _storageService.getUserProfile();

    if (_isLoggedIn && _currentUser == null) {
      _currentUser = _isGuest
          ? UserProfile.guestFarmer()
          : UserProfile.defaultFarmer();
    }
    notifyListeners();
  }

  /// Real account registration against Cotton Guard backend
  Future<bool> signup({
    required String fullName,
    required String email,
    required String password,
    String phone = '',
    String location = 'Warangal, Telangana',
    String role = 'Cotton Farmer',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        location: location,
        role: role,
      );

      final token = res['token'] as String? ?? '';
      final userMap = res['user'] as Map<String, dynamic>;
      final user = UserProfile.fromJson(userMap);

      _currentUser = user;
      _isLoggedIn = true;
      _isGuest = false;

      await _storageService.setAuthToken(token);
      await _storageService.setUserProfile(user);
      await _storageService.setLoggedIn(true);
      await _storageService.setGuest(false);

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Real account login against Cotton Guard backend
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _apiService.login(
        email: email,
        password: password,
      );

      final token = res['token'] as String? ?? '';
      final userMap = res['user'] as Map<String, dynamic>;
      final user = UserProfile.fromJson(userMap);

      _currentUser = user;
      _isLoggedIn = true;
      _isGuest = false;

      await _storageService.setAuthToken(token);
      await _storageService.setUserProfile(user);
      await _storageService.setLoggedIn(true);
      await _storageService.setGuest(false);

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Genuine Google Sign-In with Google Play Services and backend profile exchange
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('[GoogleAuth] === Stage 1/3: Google Account Selection ===');
      final account = await _googleAuthService.signIn();
      if (account == null) {
        debugPrint('[GoogleAuth] Sign in cancelled or dismissed by user.');
        _errorMessage = 'Sign in was cancelled';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      debugPrint('[GoogleAuth] === Stage 2/3: Obtaining ID Token from Play Services ===');
      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.trim().isEmpty) {
        debugPrint('[GoogleAuth] Stage 2/3 FAILED: Google Play Services did not return an ID token.');
        throw GoogleAuthException(
          'Google Play Services did not provide an ID token for backend authentication. '
          'Verify that Web client ID (${ApiConstants.googleServerClientId}) is configured '
          'under the same Google Cloud project as your Android OAuth client.',
          code: 'NO_ID_TOKEN',
          isConfigurationError: true,
        );
      }

      debugPrint('[GoogleAuth] === Stage 3/3: Backend Exchange & Cryptographic Verification ===');
      final res = await _apiService.googleAuth(
        email: account.email,
        fullName: account.displayName ?? 'Google Farmer',
        photoUrl: account.photoUrl,
        idToken: idToken.trim(),
      );

      final token = res['token'] as String? ?? '';
      final userMap = res['user'] as Map<String, dynamic>;
      final user = UserProfile.fromJson(userMap);

      _currentUser = user;
      _isLoggedIn = true;
      _isGuest = false;

      await _storageService.setAuthToken(token);
      await _storageService.setUserProfile(user);
      await _storageService.setLoggedIn(true);
      await _storageService.setGuest(false);

      debugPrint('[GoogleAuth] Authentication complete. Welcome ${user.fullName} (${user.email})');
      _isLoading = false;
      notifyListeners();
      return true;
    } on GoogleAuthException catch (e) {
      debugPrint('[GoogleAuth] Caught GoogleAuthException: ${e.message}');
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      debugPrint('[GoogleAuth] Caught backend ApiException (${e.statusCode}): ${e.message}');
      _errorMessage = 'Backend authentication failed: ${e.message}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[GoogleAuth] Caught unexpected exception: $e');
      _errorMessage = 'Google sign in failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Continues exploration without requiring credentials
  Future<void> continueAsGuest() async {
    final guest = UserProfile.guestFarmer();
    _currentUser = guest;
    _isLoggedIn = true;
    _isGuest = true;

    await _storageService.setUserProfile(guest);
    await _storageService.setLoggedIn(true);
    await _storageService.setGuest(true);

    notifyListeners();
  }

  /// Initiates password reset for forgotten credentials
  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.forgotPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Password reset request failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Resets password with secure token
  Future<bool> resetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.resetPassword(
        email: email,
        resetToken: resetToken,
        newPassword: newPassword,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Password reset failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Updates profile information locally and notifies listeners
  Future<void> updateProfile(UserProfile updated) async {
    _currentUser = updated;
    await _storageService.setUserProfile(updated);
    notifyListeners();
  }

  /// Cleans up session tokens without clearing onboarding completion
  Future<void> logout() async {
    await _googleAuthService.signOut();
    await _storageService.clearUserSession();

    _currentUser = null;
    _isLoggedIn = false;
    _isGuest = false;

    notifyListeners();
  }
}
