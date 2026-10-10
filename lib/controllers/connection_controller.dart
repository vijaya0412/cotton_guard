import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/server_health.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// Manages central server connection state, health checks, and reconnection.
class ConnectionController extends ChangeNotifier {
  final ApiService _apiService;
  final StorageService _storageService;

  ServerHealth _health = ServerHealth.checking();
  Timer? _periodicTimer;
  bool _isChecking = false;

  ConnectionController(this._apiService, this._storageService) {
    checkConnection();
    _startPeriodicCheck();
  }

  ServerHealth get health => _health;
  bool get isConnected => _health.isConnected;
  bool get isChecking => _isChecking;
  String get currentUrl => _storageService.getServerUrl();

  void _startPeriodicCheck() {
    _periodicTimer?.cancel();
    // Non-aggressive interval: 30 seconds
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnection(silent: true);
    });
  }

  /// Triggers a health check against the configured server URL
  Future<void> checkConnection({bool silent = false, String? overrideUrl}) async {
    if (_isChecking) return;
    _isChecking = true;
    if (!silent) {
      _health = ServerHealth.checking();
      notifyListeners();
    }

    try {
      final res = await _apiService.checkHealth(overrideUrl: overrideUrl);
      _health = res;
    } catch (e) {
      _health = ServerHealth.disconnected(message: e.toString());
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Updates and persists server URL, then immediately validates health
  Future<void> updateServerUrl(String newUrl) async {
    await _storageService.setServerUrl(newUrl);
    await checkConnection();
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
