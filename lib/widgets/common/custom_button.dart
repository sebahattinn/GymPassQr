import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gym_pass_qr/config/theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double height;
  final bool isOutlined;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.height = 56,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final fgColor = textColor ??
        (isOutlined
            ? (backgroundColor ?? AppTheme.primaryColor)
            : Colors.white);

    final child = _buildContent(
      spinnerColor: fgColor,
      textStyle: AppTheme.button.copyWith(color: fgColor),
    );

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: text,
      value: isLoading ? 'Loading' : null,
      child: isOutlined
          ? OutlinedButton(
              onPressed: isDisabled
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, height),
                foregroundColor: fgColor, // text & icon rengi
                side: BorderSide(
                  color: isDisabled
                      ? AppTheme.dividerColor
                      : (backgroundColor ?? AppTheme.primaryColor),
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: isDisabled
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPressed!();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor ?? AppTheme.primaryColor,
                foregroundColor: fgColor,
                minimumSize: Size(double.infinity, height),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: isDisabled ? 0 : 2,
                disabledBackgroundColor: AppTheme.dividerColor,
                textStyle: AppTheme.button,
              ),
              child: child,
            ),
    );
  }

  Widget _buildContent(
      {required Color spinnerColor, required TextStyle textStyle}) {
    if (isLoading) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          color: spinnerColor,
          strokeWidth: 2,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text, style: textStyle),
          const SizedBox(width: 8),
          Icon(icon, size: 20),
        ],
      );
    }

    return Text(text, style: textStyle);
  }
}
