import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

enum ButtonVariant { primary, secondary, outline, text, danger }

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final EdgeInsetsGeometry? padding;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.padding,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide? border;

    switch (widget.variant) {
      case ButtonVariant.primary:
        bg = isDark ? AppColors.secondary : AppColors.primary;
        fg = isDark ? AppColors.backgroundDark : Colors.white;
        break;
      case ButtonVariant.secondary:
        bg = isDark ? AppColors.surfaceDark : AppColors.secondary.withAlpha(50);
        fg = isDark ? AppColors.secondary : AppColors.primaryDark;
        break;
      case ButtonVariant.outline:
        bg = Colors.transparent;
        fg = isDark ? AppColors.secondary : AppColors.primary;
        border = BorderSide(color: fg, width: 1.5);
        break;
      case ButtonVariant.danger:
        bg = AppColors.danger;
        fg = Colors.white;
        break;
      case ButtonVariant.text:
        bg = Colors.transparent;
        fg = isDark ? AppColors.secondary : AppColors.primary;
        break;
    }

    Widget content = widget.isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                widget.text,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          );

    return AnimatedScale(
      scale: _isPressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: SizedBox(
        width: widget.width,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            onHighlightChanged: (highlighted) {
              if (mounted) setState(() => _isPressed = highlighted);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: widget.padding ??
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: border != null ? Border.fromBorderSide(border) : null,
              ),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
