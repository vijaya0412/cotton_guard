import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants/app_colors.dart';
import '../../constants/canonical_classes.dart';
import '../../constants/cotton_assets.dart';
import '../../services/storage_service.dart';
import '../../controllers/connection_controller.dart';
import '../../controllers/history_controller.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/glass_card.dart';
import '../settings/server_connection_screen.dart';
import 'image_preview_screen.dart';

class ScanScreen extends StatefulWidget {
  final StorageService storageService;
  final ConnectionController connectionController;
  final HistoryController historyController;

  const ScanScreen({
    super.key,
    required this.storageService,
    required this.connectionController,
    required this.historyController,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  bool _isPicking = false;
  bool _isFlashing = false;

  late AnimationController _guideController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _bracketOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _guideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _scanLineAnimation = CurvedAnimation(
      parent: _guideController,
      curve: Curves.easeInOut,
    );

    _bracketOpacityAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _guideController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _guideController.dispose();
    super.dispose();
  }

  Future<void> _captureWithFlash(ImageSource source) async {
    if (_isPicking) return;
    setState(() {
      _isPicking = true;
      _isFlashing = true;
    });

    // Brief realistic capture flash effect (80ms)
    await Future.delayed(const Duration(milliseconds: 80));
    if (mounted) setState(() => _isFlashing = false);

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );

      if (file != null && mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 320),
            pageBuilder: (context, animation, secondaryAnimation) =>
                ImagePreviewScreen(
              imageFile: File(file.path),
              storageService: widget.storageService,
              connectionController: widget.connectionController,
              historyController: widget.historyController,
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera access error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _selectSampleAsset(String assetPath) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, animation, secondaryAnimation) =>
            ImagePreviewScreen(
          assetPath: assetPath,
          storageService: widget.storageService,
          connectionController: widget.connectionController,
          historyController: widget.historyController,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _showGuidanceDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    color: AppColors.accent, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Best Scanning Practice',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGuidelineRow(Icons.wb_sunny_outlined,
                'Natural Lighting: Shoot under daylight, avoiding severe shadows.'),
            const SizedBox(height: 10),
            _buildGuidelineRow(Icons.crop_free_rounded,
                'Full Leaf Coverage: Fill 70% of the viewfinder with the cotton leaf.'),
            const SizedBox(height: 10),
            _buildGuidelineRow(Icons.filter_center_focus_rounded,
                'Sharp Focus: Hold steady to capture distinct veins and spot margins.'),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Understood',
              width: double.infinity,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuidelineRow(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 18, color: isDark ? AppColors.secondary : AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Scan Cotton Leaf'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Scanning Guidance',
            onPressed: _showGuidanceDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet_rounded),
            tooltip: 'Server Connection',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServerConnectionScreen(
                    connectionController: widget.connectionController,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.connectionController,
          builder: (context, _) {
            final isConnected = widget.connectionController.isConnected;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.fromLTRB(
                20.0,
                12.0,
                20.0,
                24.0 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Server connection banner if offline
                  if (!isConnected) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AppColors.warning.withAlpha(120)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              color: AppColors.warning, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Offline mode: Sample leaf testing available. Connect AI server for live model inference.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textPrimaryLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Large Photographic Camera Viewport with Corner Scanning Brackets
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      // Dynamic, responsive height matching camera 4:3 preview ratio on phones
                      final previewHeight = (availableWidth * 0.74).clamp(250.0, 310.0);
                      const double frameTop = 22.0;
                      const double frameBottom = 60.0;
                      const double frameHorizontal = 22.0;
                      final double scanSweepDistance = previewHeight - frameTop - frameBottom - 8.0;

                      return Container(
                        height: previewHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(isDark ? 90 : 30),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22.5),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Photographic viewfinder backdrop centered and balanced
                              Image.asset(
                                CottonAssets.scanCardHero,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                              ),

                              // Multi-stop vignette scrim: preserves leaf clarity while elevating HUD & text readability
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withAlpha(150),
                                      Colors.black.withAlpha(45),
                                      Colors.black.withAlpha(190),
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),

                              // Flash overlay on capture
                              if (_isFlashing)
                                Container(
                                  color: Colors.white.withAlpha(220),
                                ),

                              // Top HUD Camera Status Chip
                              Positioned(
                                top: 12,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(150),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withAlpha(35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Text(
                                          'ACTIVE VIEWFINDER',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Pulsing White Corner Scanning Brackets (positioned within frame bounds)
                              AnimatedBuilder(
                                animation: _bracketOpacityAnimation,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _bracketOpacityAnimation.value,
                                    child: child,
                                  );
                                },
                                child: const _CornerScanningBrackets(
                                  topOffset: frameTop,
                                  bottomOffset: frameBottom,
                                  horizontalOffset: frameHorizontal,
                                ),
                              ),

                              // Subtle Vertical Scan Guide Line (calm agricultural laser, confined inside frame)
                              AnimatedBuilder(
                                animation: _scanLineAnimation,
                                builder: (context, child) {
                                  return Positioned(
                                    top: frameTop + 4 + (_scanLineAnimation.value * scanSweepDistance),
                                    left: frameHorizontal + 10,
                                    right: frameHorizontal + 10,
                                    child: Container(
                                      height: 2,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight.withAlpha(220),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withAlpha(140),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Instruction: "Place a clear cotton leaf inside the frame" (positioned cleanly at bottom)
                              Positioned(
                                bottom: 12,
                                left: 24,
                                right: 24,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(185),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withAlpha(35)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.center_focus_strong_rounded,
                                          color: AppColors.primaryLight,
                                          size: 15,
                                        ),
                                        SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            'Place a clear cotton leaf inside the frame',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Administrator Paused Banner
                  ListenableBuilder(
                    listenable: widget.connectionController,
                    builder: (context, _) {
                      if (!widget.connectionController.health.isStopped) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withAlpha(80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pause_circle_filled_rounded, color: AppColors.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'AI inference service is paused by the administrator. Scans are temporarily unavailable.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.warningLight : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 18),

                  // Bottom Capture Buttons: Photo & Gallery
                  ListenableBuilder(
                    listenable: widget.connectionController,
                    builder: (context, _) {
                      final isStopped = widget.connectionController.health.isStopped;
                      return Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'Take Photo',
                              icon: Icons.camera_alt_rounded,
                              isLoading: _isPicking,
                              onPressed: isStopped
                                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('AI inference is paused by the administrator. Please check back later.')),
                                      )
                                  : () => _captureWithFlash(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: CustomButton(
                              text: 'Gallery',
                              icon: Icons.photo_library_outlined,
                              variant: ButtonVariant.secondary,
                              isLoading: _isPicking,
                              onPressed: isStopped
                                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('AI inference is paused by the administrator. Please check back later.')),
                                      )
                                  : () => _captureWithFlash(ImageSource.gallery),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),

                  // Quick Field Test Samples Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Verified Field Samples',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Tap to analyze',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textMutedDark
                              : AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Instant diagnosis testing with authentic project disease captures:',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grid of authentic disease leaf thumbnails
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1.3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: CanonicalClasses.all.length,
                    itemBuilder: (context, index) {
                      final clsName = CanonicalClasses.all[index];
                      final assetPath =
                          CanonicalClasses.getPrimaryAssetImage(clsName);

                      return GlassCard(
                        onTap: () => _selectSampleAsset(assetPath),
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(assetPath, fit: BoxFit.cover),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withAlpha(180),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Text(
                                  clsName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CornerScanningBrackets extends StatelessWidget {
  final double topOffset;
  final double bottomOffset;
  final double horizontalOffset;

  const _CornerScanningBrackets({
    this.topOffset = 22,
    this.bottomOffset = 60,
    this.horizontalOffset = 22,
  });

  @override
  Widget build(BuildContext context) {
    const double length = 26;
    const double thickness = 3.5;
    const color = Colors.white;

    return Stack(
      children: [
        // Top-Left
        Positioned(
          top: topOffset,
          left: horizontalOffset,
          child: SizedBox(
            width: length,
            height: length,
            child: CustomPaint(
              painter: _BracketPainter(
                  top: true, left: true, color: color, thickness: thickness),
            ),
          ),
        ),
        // Top-Right
        Positioned(
          top: topOffset,
          right: horizontalOffset,
          child: SizedBox(
            width: length,
            height: length,
            child: CustomPaint(
              painter: _BracketPainter(
                  top: true, left: false, color: color, thickness: thickness),
            ),
          ),
        ),
        // Bottom-Left
        Positioned(
          bottom: bottomOffset,
          left: horizontalOffset,
          child: SizedBox(
            width: length,
            height: length,
            child: CustomPaint(
              painter: _BracketPainter(
                  top: false, left: true, color: color, thickness: thickness),
            ),
          ),
        ),
        // Bottom-Right
        Positioned(
          bottom: bottomOffset,
          right: horizontalOffset,
          child: SizedBox(
            width: length,
            height: length,
            child: CustomPaint(
              painter: _BracketPainter(
                  top: false, left: false, color: color, thickness: thickness),
            ),
          ),
        ),
      ],
    );
  }
}

class _BracketPainter extends CustomPainter {
  final bool top;
  final bool left;
  final Color color;
  final double thickness;

  _BracketPainter({
    required this.top,
    required this.left,
    required this.color,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
