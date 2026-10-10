import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../models/scan_record.dart';
import '../models/user_profile.dart';

/// Centralized Local Storage & Persistence Service.
class StorageService {
  static const String _keyServerUrl = 'cotton_guard_server_url';
  static const String _keyThemeMode = 'cotton_guard_theme_mode';
  static const String _keyIsLoggedIn = 'cotton_guard_is_logged_in';
  static const String _keyUserProfile = 'cotton_guard_user_profile';
  static const String _keyScanHistory = 'cotton_guard_scan_history';
  static const String _keyNotifications = 'cotton_guard_notifications';
  static const String _keyHasSeenOnboarding = 'cotton_guard_has_seen_onboarding';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Server URL ---
  String getServerUrl() {
    final saved = _prefs.getString(_keyServerUrl);
    if (saved != null && saved.isNotEmpty) {
      return ApiConstants.normalizeBaseUrl(saved);
    }

    // Default dynamically based on platform:
    // Android Emulator -> 10.0.2.2:8000/api/v1
    // Otherwise -> 127.0.0.1:8000/api/v1
    if (!kIsWeb && Platform.isAndroid) {
      return ApiConstants.defaultEmulatorUrl;
    }
    return ApiConstants.defaultLocalhostUrl;
  }

  Future<void> setServerUrl(String url) async {
    final normalized = ApiConstants.normalizeBaseUrl(url);
    await _prefs.setString(_keyServerUrl, normalized);
  }

  // --- Theme Mode ---
  // Returns 'system', 'light', 'dark'
  String getThemeMode() {
    return _prefs.getString(_keyThemeMode) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }

  // --- Onboarding ---
  bool hasSeenOnboarding() {
    return _prefs.getBool(_keyHasSeenOnboarding) ?? false;
  }

  Future<void> setHasSeenOnboarding(bool val) async {
    await _prefs.setBool(_keyHasSeenOnboarding, val);
  }

  // --- Authentication ---
  static const String _keyAuthToken = 'cotton_guard_auth_token';
  static const String _keyIsGuest = 'cotton_guard_is_guest';

  bool isLoggedIn() {
    return _prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  Future<void> setLoggedIn(bool val) async {
    await _prefs.setBool(_keyIsLoggedIn, val);
  }

  bool isGuest() {
    return _prefs.getBool(_keyIsGuest) ?? false;
  }

  Future<void> setGuest(bool val) async {
    await _prefs.setBool(_keyIsGuest, val);
  }

  String? getAuthToken() {
    return _prefs.getString(_keyAuthToken);
  }

  Future<void> setAuthToken(String? token) async {
    if (token == null) {
      await _prefs.remove(_keyAuthToken);
    } else {
      await _prefs.setString(_keyAuthToken, token);
    }
  }

  UserProfile? getUserProfile() {
    final str = _prefs.getString(_keyUserProfile);
    if (str == null || str.isEmpty) return null;
    try {
      final json = jsonDecode(str) as Map<String, dynamic>;
      return UserProfile.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> setUserProfile(UserProfile profile) async {
    await _prefs.setString(_keyUserProfile, jsonEncode(profile.toJson()));
  }

  Future<void> clearUserSession() async {
    await _prefs.remove(_keyIsLoggedIn);
    await _prefs.remove(_keyAuthToken);
    await _prefs.remove(_keyIsGuest);
  }

  // --- Scan History ---
  List<ScanRecord> getScanHistory() {
    final str = _prefs.getString(_keyScanHistory);
    if (str == null || str.isEmpty) return [];
    return ScanRecord.decodeList(str);
  }

  Future<void> saveScanRecord(ScanRecord record) async {
    final current = getScanHistory();
    current.insert(0, record);
    // Keep up to 100 recent scans
    if (current.length > 100) {
      current.removeRange(100, current.length);
    }
    await _prefs.setString(_keyScanHistory, ScanRecord.encodeList(current));
  }

  Future<void> deleteScanRecord(String id) async {
    final current = getScanHistory();
    current.removeWhere((r) => r.id == id);
    await _prefs.setString(_keyScanHistory, ScanRecord.encodeList(current));
  }

  Future<void> clearAllHistory() async {
    await _prefs.remove(_keyScanHistory);
  }

  // --- Notifications ---
  bool getNotificationsEnabled() {
    return _prefs.getBool(_keyNotifications) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyNotifications, enabled);
  }

  // --- Weather Cache ---
  static const String _keyCachedWeather = 'cotton_guard_cached_weather';
  static const String _keyWeatherCacheTime = 'cotton_guard_weather_cache_time';

  String? getCachedWeatherJson() {
    return _prefs.getString(_keyCachedWeather);
  }

  int? getWeatherCacheTimestamp() {
    return _prefs.getInt(_keyWeatherCacheTime);
  }

  Future<void> setCachedWeather(String jsonStr, int timestampMs) async {
    await _prefs.setString(_keyCachedWeather, jsonStr);
    await _prefs.setInt(_keyWeatherCacheTime, timestampMs);
  }

  Future<void> clearCachedWeather() async {
    await _prefs.remove(_keyCachedWeather);
    await _prefs.remove(_keyWeatherCacheTime);
  }
}
