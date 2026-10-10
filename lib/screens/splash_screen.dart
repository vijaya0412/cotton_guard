import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/cotton_assets.dart';
import '../services/storage_service.dart';
import 'onboarding_screen.dart';
import 'main_navigation_shell.dart';
import 'auth/login_screen.dart';

/// Clean, minimal, premium opening splash screen for Cotton Guard.
class SplashScreen extends StatefulWidget {
  final StorageService storageService;

  const SplashScreen({super.key, required this.storageService});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _loaderFadeAnimation;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Subtle gentle fade & small scale transition for logo
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    // Subtle typography fade
    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );

    // Restrained loader fade
    _loaderFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
      ),
    );

    _animController.forward();

    // Responsive transition without artificial lag (1.5 seconds total)
    _navigationTimer = Timer(const Duration(milliseconds: 1500), _navigateNext);
  }

  void _navigateNext() {
    if (!mounted) return;

    final hasSeenOnboarding = widget.storageService.hasSeenOnboarding();
    final isLoggedIn = widget.storageService.isLoggedIn();

    Widget nextScreen;
    if (!hasSeenOnboarding) {
      nextScreen = OnboardingScreen(storageService: widget.storageService);
    } else if (isLoggedIn) {
      nextScreen = MainNavigationShell(storageService: widget.storageService);
    } else {
      nextScreen = LoginScreen(storageService: widget.storageService);
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Design system background: clean agricultural theme palette
    final bgColor = isDark
        ? AppColors.backgroundDark
        : const Color(0xFFF7FAF8);
    final cardBg = isDark
        ? AppColors.surfaceDark
        : Colors.white;
    final primaryTextColor = isDark
        ? AppColors.textPrimaryDark
        : const Color(0xFF143026);
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF4A6B5D);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Animated Logo Container
              FadeTransition(
                opacity: _logoFadeAnimation,
                child: ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: Container(
                    width: 104,
                    height: 104,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 50 : 18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : const Color(0xFFE2EBE5),
                        width: 1.5,
                      ),
                    ),
                    child: Image.asset(
                      CottonAssets.logo,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Refined Typography
              FadeTransition(
                opacity: _textFadeAnimation,
                child: Column(
                  children: [
                    Text(
                      'Cotton Guard',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Smart Crop Protection & Advisory',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Restrained, Minimal Loading Indicator
              FadeTransition(
                opacity: _loaderFadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isDark ? AppColors.secondary : AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Empowering Indian Cotton Farmers',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: secondaryTextColor.withAlpha(190),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
