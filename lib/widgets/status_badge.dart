import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final bool hasDot;

  const StatusBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
    this.hasDot = false,
  });

  factory StatusBadge.serverStatus(String status, {int? latencyMs}) {
    Color bg;
    Color fg;
    String text = status;

    switch (status) {
      case 'CONNECTED':
        bg = AppColors.successLight;
        fg = AppColors.success;
        text = latencyMs != null && latencyMs > 0 ? 'AI Online (${latencyMs}ms)' : 'AI Online';
        break;
      case 'CHECKING':
        bg = AppColors.infoLight;
        fg = AppColors.info;
        text = 'Checking AI...';
        break;
      case 'STOPPED':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        text = 'Service Paused';
        break;
      case 'STARTING':
      case 'STOPPING':
        bg = AppColors.infoLight;
        fg = AppColors.info;
        text = status == 'STARTING' ? 'Starting AI...' : 'Stopping AI...';
        break;
      case 'MODEL_NOT_READY':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        text = 'Model Not Ready';
        break;
      default:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        text = 'AI Offline';
    }

    return StatusBadge(
      label: text,
      backgroundColor: bg,
      textColor: fg,
      hasDot: true,
    );
  }

  factory StatusBadge.severity(String severity, int level) {
    Color bg;
    Color fg;

    switch (level) {
      case 0:
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 1:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0369A1);
        break;
      case 2:
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case 3:
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFC2410C);
        break;
      default:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
    }

    return StatusBadge(
      label: severity,
      backgroundColor: bg,
      textColor: fg,
      icon: level == 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
    );
  }

  factory StatusBadge.confidence(double conf) {
    final pct = (conf * 100).toStringAsFixed(1);
    final isHigh = conf >= 0.70;
    final isModerate = conf >= 0.50 && conf < 0.70;

    Color bg = isHigh
        ? AppColors.successLight
        : (isModerate ? AppColors.warningLight : AppColors.dangerLight);
    Color fg = isHigh
        ? AppColors.success
        : (isModerate ? AppColors.warning : AppColors.danger);

    return StatusBadge(
      label: '$pct% Confidence',
      backgroundColor: bg,
      textColor: fg,
      icon: Icons.psychology_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
