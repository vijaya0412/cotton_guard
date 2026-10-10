import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/cotton_assets.dart';
import '../services/storage_service.dart';
import 'auth/login_screen.dart';

/// Comprehensive 4-Page Onboarding Experience for Cotton Guard.
class OnboardingScreen extends StatefulWidget {
  final StorageService storageService;

  const OnboardingScreen({super.key, required this.storageService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Smart Cotton\nLeaf Scanning',
      'subtitle':
          'Instant AI-assisted disease diagnosis from a single photo. Our validated deep learning vision model detects 7 foliar conditions in under 30 milliseconds.',
      'icon': Icons.document_scanner_outlined,
      'badge': 'AI Vision Inference',
      'image': 'assets/diseases/healthy_leaf/healthy_leaf_1.jpg',
    },
    {
      'title': 'Disease Insights\n& Field Advisories',
      'subtitle':
          'Access verified agronomic management for bacterial blight, leaf curl virus, jassid burns, and nutrient reddening with chemical, IPM, and organic dosages.',
      'icon': Icons.medical_services_outlined,
      'badge': 'Agronomic Database',
      'image': 'assets/diseases/bacterial_blight/bacterial_blight_1.jpg',
    },
    {
      'title': 'Location-Aware\nWeather & Alerts',
      'subtitle':
          'Stay ahead of vector infestations and spray windows with real-time temperature, humidity, wind conditions, and district-level agricultural advisories across India.',
      'icon': Icons.wb_sunny_outlined,
      'badge': 'Live Field Weather',
      'image': 'assets/diseases/leaf_hopper_jassids/leaf_hopper_jassids_1.jpg',
    },
    {
      'title': 'Cotton Guard\nSmart Crop Health',
      'subtitle':
          'Join cotton farmers across Telangana, Maharashtra, Gujarat, and all 28 Indian states safeguarding crop health with instant AI disease diagnosis.',
      'icon': Icons.eco_outlined,
      'badge': 'Cotton Guard AI',
      'image': CottonAssets.logo,
      'isLogo': true,
    },
  ];

  Future<void> _markOnboardingComplete() async {
    await widget.storageService.setHasSeenOnboarding(true);
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onSkip() {
    _goToLogin();
  }

  void _goToLogin() async {
    await _markOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(storageService: widget.storageService),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLastPage = _currentPage == _pages.length - 1;

    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final cardColor = isDark ? AppColors.surfaceDark : Colors.white;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : const Color(0xFF143026);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF4A6B5D);

    return PopScope(
      canPop: _currentPage == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentPage > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar with Logo & Skip Action
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : const Color(0xFFE2EBE5),
                            ),
                          ),
                          child: Image.asset(
                            CottonAssets.logo,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Cotton Guard',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                    if (!isLastPage)
                      TextButton(
                        onPressed: _onSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: secondaryTextColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),

              // Horizontal PageView
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Visual Illustration / Card
                            Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : const Color(0xFFE5EDE8),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(isDark ? 50 : 12),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: page['isLogo'] == true
                                  ? Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Image.asset(
                                        CottonAssets.logo,
                                        fit: BoxFit.contain,
                                      ),
                                    )
                                  : page['image'] != null
                                      ? Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Image.asset(
                                          page['image'] as String,
                                          fit: BoxFit.cover,
                                        ),
                                        Container(
                                          color: Colors.black.withAlpha(35),
                                        ),
                                        Positioned(
                                          bottom: 12,
                                          right: 12,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(40),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              page['icon'] as IconData,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Center(
                                      child: Icon(
                                        page['icon'] as IconData,
                                        size: 72,
                                        color: isDark ? AppColors.secondary : AppColors.primary,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 24),

                            // Badge Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.secondary : AppColors.primary).withAlpha(22),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                page['badge'] as String,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: isDark ? AppColors.secondary : AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Title
                            Text(
                              page['title'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.22,
                                letterSpacing: -0.4,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Subtitle
                            Text(
                              page['subtitle'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.45,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Indicator & Actions Area
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Smooth Animated Dot Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (idx) {
                        final isActive = idx == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 260),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: isActive ? 24 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark ? AppColors.secondary : AppColors.primary)
                                : (isDark ? AppColors.borderDark : const Color(0xFFD4E0D9)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    // Single Continue Button on all slides, navigating directly to LoginScreen on last slide
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLastPage ? _goToLogin : _onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? AppColors.secondary : AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
