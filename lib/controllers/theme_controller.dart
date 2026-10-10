import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// Theme Controller supporting persistent Light and Dark mode.
class ThemeController extends ChangeNotifier {
  final StorageService _storageService;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeController(this._storageService) {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  void _loadTheme() {
    final modeStr = _storageService.getThemeMode();
    if (modeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (modeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _storageService.setThemeMode(modeStr);
    notifyListeners();
  }

  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }
}
