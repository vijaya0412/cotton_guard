import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Premium AI Scanning Animation View with smooth vertical laser beam and stage progression.
class ScanAnimationView extends StatefulWidget {
  final dynamic imageSource; // File or String (asset path)
  final String currentStageText;

  const ScanAnimationView({
    super.key,
    required this.imageSource,
    required this.currentStageText,
  });

  @override
  State<ScanAnimationView> createState() => _ScanAnimationViewState();
}

class _ScanAnimationViewState extends State<ScanAnimationView>
    with SingleTickerProviderStateMixin {
  late AnimationController _beamController;
  late Animation<double> _beamAnimation;

  @override
  void initState() {
    super.initState();
    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _beamAnimation = CurvedAnimation(
      parent: _beamController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget imageWidget;
    if (widget.imageSource is File) {
      imageWidget = Image.file(
        widget.imageSource as File,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (widget.imageSource is String) {
      imageWidget = Image.asset(
        widget.imageSource as String,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else {
      imageWidget = Container(color: Colors.grey.shade300);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Viewport with Scanning Beam and Corner Reticles
        Container(
          width: 290,
          height: 290,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.scanBeam.withAlpha(180),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.scanBeam.withAlpha(50),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                // Leaf Image Underneath
                imageWidget,

                // Subtle dark vignette to make laser pop
                Container(
                  color: Colors.black.withAlpha(60),
                ),

                // Corner Reticles
                const _CornerReticles(),

                // Animated Vertical Laser Beam
                AnimatedBuilder(
                  animation: _beamAnimation,
                  builder: (context, child) {
                    return Positioned(
                      top: _beamAnimation.value * (290 - 4),
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Glow trail
                          Container(
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppColors.scanBeam.withAlpha(90),
                                ],
                              ),
                            ),
                          ),
                          // Crisp Laser Line
                          Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.scanBeam,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.scanBeam,
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // AI Processing Badge Overlay
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.scanBeam.withAlpha(120)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.scanBeam,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'AI ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
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

        const SizedBox(height: 32),

        // Clean Stage Progress Indicator Text
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.secondary : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.currentStageText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CornerReticles extends StatelessWidget {
  const _CornerReticles();

  @override
  Widget build(BuildContext context) {
    const double length = 20;
    const double thickness = 3;
    const color = AppColors.scanBeam;

    return Stack(
      children: [
        // Top-Left
        Positioned(
          top: 10,
          left: 10,
          child: SizedBox(
            width: length,
            height: length,
            child: CustomPaint(
              painter: _ReticlePainter(top: true, left: true, color: color, thickness: thickness),
            ),
          ),
        ),
        // Top-Right
        Positioned(
          top: 10,
          right: 10,
          child: SizedBox(
            width: length,
            height: length,
            child: CustomPaint(
              painter: _ReticlePainter(top: true, left: false, color: color, thickness: thickness),
            ),
          ),
        ),
        // Bottom-Left
        Positioned(
          bottom: 10,
          left: 10,
          child: SizedBox(
            width: length,
            height: length,
            child: CustomPaint(
              painter: _ReticlePainter(top: false, left: true, color: color, thickness: thickness),
            ),
          ),
        ),
        // Bottom-Right
        Positioned(
          bottom: 10,
          right: 10,
          child: SizedBox(
            width: length,
            height: length,
            child: CustomPaint(
              painter: _ReticlePainter(top: false, left: false, color: color, thickness: thickness),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final bool top;
  final bool left;
  final Color color;
  final double thickness;

  _ReticlePainter({
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
