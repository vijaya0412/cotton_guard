import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'custom_button.dart';

enum ErrorType { poorQuality, nonCotton, serverOffline, lowConfidence, general }

class ErrorStateView extends StatelessWidget {
  final ErrorType type;
  final String title;
  final String message;
  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final Map<String, dynamic>? metrics;

  const ErrorStateView({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.secondaryButtonText,
    this.onSecondaryPressed,
    this.metrics,
  });

  factory ErrorStateView.poorQuality({
    required String message,
    required VoidCallback onRetake,
    VoidCallback? onChooseOther,
    Map<String, dynamic>? metrics,
  }) {
    return ErrorStateView(
      type: ErrorType.poorQuality,
      title: 'Image Needs a Clearer View',
      message: message,
      primaryButtonText: 'Retake Photo',
      onPrimaryPressed: onRetake,
      secondaryButtonText: onChooseOther != null ? 'Choose from Gallery' : null,
      onSecondaryPressed: onChooseOther,
      metrics: metrics,
    );
  }

  factory ErrorStateView.nonCotton({
    required String message,
    required VoidCallback onTryAgain,
    VoidCallback? onBackToHome,
    Map<String, dynamic>? metrics,
  }) {
    return ErrorStateView(
      type: ErrorType.nonCotton,
      title: 'Not a Cotton Leaf',
      message: message,
      primaryButtonText: 'Capture Cotton Leaf',
      onPrimaryPressed: onTryAgain,
      secondaryButtonText: onBackToHome != null ? 'Back to Home' : null,
      onSecondaryPressed: onBackToHome,
      metrics: metrics,
    );
  }

  factory ErrorStateView.serverOffline({
    required String message,
    required VoidCallback onConfigureServer,
    VoidCallback? onRetry,
    String? retryButtonText,
  }) {
    return ErrorStateView(
      type: ErrorType.serverOffline,
      title: 'AI Server Disconnected',
      message: message,
      primaryButtonText: 'Server Connection Settings',
      onPrimaryPressed: onConfigureServer,
      secondaryButtonText: onRetry != null ? (retryButtonText ?? 'Retry Connection') : null,
      onSecondaryPressed: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (type) {
      case ErrorType.poorQuality:
        icon = Icons.blur_on_rounded;
        iconColor = AppColors.warning;
        iconBg = AppColors.warningLight;
        break;
      case ErrorType.nonCotton:
        icon = Icons.eco_outlined;
        iconColor = const Color(0xFFC2410C);
        iconBg = const Color(0xFFFFEDD5);
        break;
      case ErrorType.serverOffline:
        icon = Icons.cloud_off_rounded;
        iconColor = AppColors.danger;
        iconBg = AppColors.dangerLight;
        break;
      case ErrorType.lowConfidence:
        icon = Icons.help_outline_rounded;
        iconColor = AppColors.accent;
        iconBg = AppColors.accentLight;
        break;
      case ErrorType.general:
        icon = Icons.error_outline_rounded;
        iconColor = AppColors.danger;
        iconBg = AppColors.dangerLight;
        break;
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: iconColor),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.45,
              ),
            ),
            if (metrics != null && metrics!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Metrics: ${metrics!.entries.map((e) => '${e.key}: ${e.value}').join(' | ')}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            CustomButton(
              text: primaryButtonText,
              onPressed: onPrimaryPressed,
              variant: ButtonVariant.primary,
              width: double.infinity,
            ),
            if (secondaryButtonText != null && onSecondaryPressed != null) ...[
              const SizedBox(height: 12),
              CustomButton(
                text: secondaryButtonText!,
                onPressed: onSecondaryPressed!,
                variant: ButtonVariant.outline,
                width: double.infinity,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
