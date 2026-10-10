import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/app_theme.dart';
import 'services/storage_service.dart';
import 'controllers/theme_controller.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for responsive mobile layout
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize persistent local storage
  final storageService = await StorageService.init();

  runApp(CottonGuardApp(storageService: storageService));
}

class CottonGuardApp extends StatefulWidget {
  final StorageService storageService;

  const CottonGuardApp({super.key, required this.storageService});

  @override
  State<CottonGuardApp> createState() => _CottonGuardAppState();
}

class _CottonGuardAppState extends State<CottonGuardApp> {
  late final ThemeController _themeController;

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController(widget.storageService);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Cotton Guard',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _themeController.themeMode,
          home: SplashScreen(storageService: widget.storageService),
        );
      },
    );
  }
}
