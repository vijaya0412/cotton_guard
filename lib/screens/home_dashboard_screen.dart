import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/cotton_assets.dart';
import '../models/weather_data.dart';
import '../models/scan_record.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/weather_service.dart';
import '../services/api_service.dart';
import '../services/indian_time_service.dart';
import '../controllers/connection_controller.dart';
import '../controllers/history_controller.dart';
import '../controllers/auth_controller.dart';
import '../widgets/status_badge.dart';
import '../widgets/glass_card.dart';
import '../widgets/user_avatar.dart';
import '../widgets/location_picker_sheet.dart';
import 'disease_library/disease_library_screen.dart';
import 'settings/server_connection_screen.dart';
import 'history/history_detail_screen.dart';
import 'insights/insights_screen.dart';
import 'advisory/advisory_screen.dart';
import 'scan/scan_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final StorageService storageService;
  final ConnectionController connectionController;
  final HistoryController historyController;
  final AuthController authController;
  final Function(int) onNavigateToTab;

  const HomeDashboardScreen({
    super.key,
    required this.storageService,
    required this.connectionController,
    required this.historyController,
    required this.authController,
    required this.onNavigateToTab,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with WidgetsBindingObserver {
  late final WeatherService _weatherService;
  WeatherData? _weather;
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    _weatherService = WeatherService(widget.storageService);
    WidgetsBinding.instance.addObserver(this);
    _loadWeather();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        setState(() {});
        _loadWeather();
      }
    }
  }

  Future<void> _loadWeather({
    bool forceRefresh = false,
    String? locationOverride,
    double? latOverride,
    double? lonOverride,
  }) async {
    setState(() => _isLoadingWeather = true);
    final user = widget.authController.currentUser;
    final location = locationOverride ?? user?.location ?? 'Warangal, Telangana';
    final lat = latOverride ?? user?.latitude;
    final lon = lonOverride ?? user?.longitude;
    final w = await _weatherService.fetchWeather(
      location: location,
      latitude: lat,
      longitude: lon,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    setState(() {
      _weather = w;
      _isLoadingWeather = false;
    });
  }

  String _getGreeting() {
    return '${IndianTimeService.getGreeting()},';
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = widget.authController.currentUser;
    final rawName = user?.fullName;
    final userName = (rawName != null && rawName.trim().isNotEmpty) ? rawName.trim() : 'Farmer';
    final location = user?.location ?? 'Warangal, Telangana';

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              _loadWeather(),
              widget.connectionController.checkConnection(),
            ]);
          },
          child: ListenableBuilder(
            listenable: Listenable.merge([
              widget.connectionController,
              widget.historyController,
              widget.authController,
            ]),
            builder: (context, _) {
              final health = widget.connectionController.health;
              final recentScans = widget.historyController.records;
              final ScanRecord? latestScan =
                  recentScans.isNotEmpty ? recentScans.first : null;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar / User Profile Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),

                        // Profile Avatar & Server Health Pill
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ServerConnectionScreen(
                                      connectionController:
                                          widget.connectionController,
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: StatusBadge.serverStatus(
                                health.status,
                                latencyMs: health.latencyMs,
                              ),
                            ),
                            const SizedBox(width: 10),
                            UserAvatar(
                              imagePath: user?.profileImagePath,
                              radius: 22,
                              onTap: () => widget.onNavigateToTab(3), // Navigate to Profile tab
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Weather & Location Card (Dynamic)
                    _buildWeatherCard(isDark, location),
                    const SizedBox(height: 18),

                    // Large Photographic Scan Cotton Leaf Hero Card
                    _buildScanHeroCard(isDark),
                    const SizedBox(height: 22),

                    // Quick Action Cards: Disease Library & Field Insights
                    Row(
                      children: [
                        Expanded(
                          child: GlassCard(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const DiseaseLibraryScreen(),
                                ),
                              );
                            },
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(
                                    'assets/diseases/bacterial_blight/bacterial_blight_1.jpg',
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Disease Library',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '7 Conditions',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.textMutedDark
                                              : AppColors.textMutedLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GlassCard(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InsightsScreen(
                                    historyController: widget.historyController,
                                  ),
                                ),
                              );
                            },
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withAlpha(25),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.analytics_outlined,
                                    color: AppColors.accent,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Field Insights',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${widget.historyController.totalScans} Total Scans',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.textMutedDark
                                              : AppColors.textMutedLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // Recent Scans Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Scans',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        if (recentScans.isNotEmpty)
                          GestureDetector(
                            onTap: () => widget.onNavigateToTab(1), // History tab
                            child: Text(
                              'View All (${recentScans.length})',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.secondary
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Recent Scan Card or Empty State
                    if (latestScan == null)
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 22),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (isDark
                                        ? AppColors.secondary
                                        : AppColors.primary)
                                    .withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.center_focus_weak_rounded,
                                color: isDark
                                    ? AppColors.secondary
                                    : AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No scans recorded yet',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Scan a cotton leaf to diagnose symptoms and view treatments.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _buildRecentScanCard(latestScan, isDark),

                    const SizedBox(height: 20),

                    // Treatment Advisory Banner Card
                    _buildAdvisoryBanner(isDark),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _openLocationPicker(BuildContext context, String currentLocation) {
    LocationPickerSheet.show(
      context: context,
      currentLocation: currentLocation,
      onLocationSelected: (selected) async {
        final current = widget.authController.currentUser ?? UserProfile.defaultFarmer();
        final updated = current.copyWith(
          location: selected.displayName,
          latitude: selected.latitude,
          longitude: selected.longitude,
        );
        await widget.authController.updateProfile(updated);
        if (mounted) {
          _loadWeather(
            locationOverride: selected.displayName,
            latOverride: selected.latitude,
            lonOverride: selected.longitude,
          );
        }
      },
    );
  }

  void _handleStartScan(BuildContext context) {
    if (!widget.connectionController.isConnected) {
      _showServerRequiredDialog(context);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          storageService: widget.storageService,
          connectionController: widget.connectionController,
          historyController: widget.historyController,
        ),
      ),
    );
  }

  void _showServerRequiredDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: AppColors.danger,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'AI Server Offline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cotton leaf disease scanning and deep AI vision diagnosis require an active connection to the Cotton Guard AI server.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black.withAlpha(8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_off_rounded, size: 16, color: AppColors.textMutedLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.connectionController.currentUrl,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'Roboto',
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.connectionController.checkConnection();
            },
            child: const Text('Retry'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServerConnectionScreen(
                    connectionController: widget.connectionController,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.secondary : AppColors.primary,
              foregroundColor: isDark ? AppColors.backgroundDark : Colors.white,
            ),
            child: const Text('Server Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard(bool isDark, String location) {
    if (_isLoadingWeather) {
      return Container(
        height: 78,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final w = _weather;
    final isAvail = w?.isAvailable ?? false;

    return GlassCard(
      onTap: () => _openLocationPicker(context, location),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.secondary : AppColors.primary)
                            .withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAvail ? Icons.wb_sunny_rounded : Icons.cloud_outlined,
                        color: isDark ? AppColors.secondary : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 13,
                                color: isDark ? AppColors.secondary : AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  location,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.edit_location_alt_outlined,
                                size: 13,
                                color: isDark ? AppColors.secondary : AppColors.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isAvail
                                ? '${w!.weatherCondition} • Humidity ${w.humidityFormatted} • Wind ${w.windSpeedFormatted}'
                                : 'Weather Offline • Tap to select location',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAvail) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          w!.temperatureFormatted,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: w.isCached
                                ? AppColors.warning.withAlpha(25)
                                : AppColors.success.withAlpha(25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            w.freshnessLabel,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: w.isCached ? AppColors.warning : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: isDark ? AppColors.secondary : AppColors.primary,
                    ),
                    tooltip: 'Refresh Weather',
                    onPressed: () => _loadWeather(forceRefresh: true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
          if (isAvail && w?.advisoryWarning != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: AppColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      w!.advisoryWarning!,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScanHeroCard(bool isDark) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 195),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132A1F) : const Color(0xFF164436),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF164436).withAlpha(isDark ? 80 : 45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Authentic Photographic Cotton Leaf Integrated into Right Side
            Positioned(
              right: -20,
              top: 0,
              bottom: 0,
              width: 220,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black87,
                      Colors.black,
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  CottonAssets.scanCardHero,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Left Content: AI Badge, Title, Description, Quick Scan Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 5),
                        Text(
                          'AI VISION 1.0',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan Cotton Leaf',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 180,
                    child: Text(
                      'Detect diseases & receive expert guidance instantly.',
                      style: TextStyle(
                        color: Colors.white.withAlpha(220),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Start Scan Button
                  ElevatedButton.icon(
                    onPressed: () => _handleStartScan(context),
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: const Text('Start Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF133B2E),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRecentScanCard(ScanRecord scan, bool isDark) {
    return GlassCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HistoryDetailScreen(
              record: scan,
              historyController: widget.historyController,
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: scan.imagePath.startsWith('assets/')
                  ? Image.asset(scan.imagePath, fit: BoxFit.cover)
                  : (File(scan.imagePath).existsSync()
                      ? Image.file(File(scan.imagePath), fit: BoxFit.cover)
                      : Image.asset(CottonAssets.logo, fit: BoxFit.contain)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        scan.predictedClass,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    StatusBadge.severity(scan.severity, scan.severityLevel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${(scan.confidence * 100).toStringAsFixed(1)}% Confidence • ${scan.timestamp.day}/${scan.timestamp.month}/${scan.timestamp.year}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvisoryBanner(bool isDark) {
    return GlassCard(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdvisoryScreen(
              storageService: widget.storageService,
              apiService: ApiService(widget.storageService),
            ),
          ),
        );
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_outline_rounded,
                color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agronomic Advisory & IPM',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Learn spray schedules, fertilizer management & vector barriers.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: isDark ? AppColors.secondary : AppColors.primary,
          ),
        ],
      ),
    );
  }
}
