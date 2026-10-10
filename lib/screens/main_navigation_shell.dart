import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../controllers/connection_controller.dart';
import '../controllers/history_controller.dart';
import '../controllers/auth_controller.dart';
import 'home_dashboard_screen.dart';
import 'history/history_screen.dart';
import 'insights/insights_screen.dart';
import 'profile/profile_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final StorageService storageService;
  final int initialIndex;

  const MainNavigationShell({
    super.key,
    required this.storageService,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  late final ApiService _apiService;
  late final ConnectionController _connectionController;
  late final HistoryController _historyController;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _apiService = ApiService(widget.storageService);
    _connectionController =
        ConnectionController(_apiService, widget.storageService);
    _historyController = HistoryController(widget.storageService);
    _authController = AuthController(widget.storageService);
  }

  @override
  void dispose() {
    _connectionController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex != index) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<Widget> screens = [
      HomeDashboardScreen(
        storageService: widget.storageService,
        connectionController: _connectionController,
        historyController: _historyController,
        authController: _authController,
        onNavigateToTab: _onTabSelected,
      ),
      HistoryScreen(
        storageService: widget.storageService,
        historyController: _historyController,
      ),
      InsightsScreen(
        historyController: _historyController,
      ),
      ProfileScreen(
        storageService: widget.storageService,
        authController: _authController,
        connectionController: _connectionController,
      ),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1,
              ),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 16,
                      offset: const Offset(0, -3),
                    ),
                  ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                  _buildNavItem(1, Icons.history_rounded, Icons.history_toggle_off_rounded, 'History'),
                  _buildNavItem(2, Icons.insights_outlined, Icons.insights_rounded, 'Insights'),
                  _buildNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeColor = isDark ? AppColors.secondary : AppColors.primary;
    final inactiveColor =
        isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(14),
      splashColor: (isDark ? AppColors.secondary : AppColors.primary).withAlpha(20),
      highlightColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(
                isSelected ? filledIcon : outlineIcon,
                size: 23,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                fontFamily: 'Roboto',
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

