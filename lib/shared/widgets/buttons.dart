import 'package:flutter/material.dart';
import 'package:scompass_07/config/theme.dart';

enum SCompassButtonVariant {
  filled,
  outlined,
  text
}

class SCompassButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final SCompassButtonVariant variant;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;

  const SCompassButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.variant = SCompassButtonVariant.filled,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 48,
    this.borderRadius = AppTheme.borderRadiusMedium,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      height: height,
      child: _buildButton(theme),
    );
  }

  Widget _buildButton(ThemeData theme) {
    switch (variant) {
      case SCompassButtonVariant.outlined:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(
              color: backgroundColor ?? theme.primaryColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: _buildChild(theme),
        );
      case SCompassButtonVariant.text:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: _buildChild(theme),
        );
      case SCompassButtonVariant.filled:
      default:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? theme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
          child: _buildChild(theme),
        );
    }
  }

  Widget _buildChild(ThemeData theme) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            variant == SCompassButtonVariant.filled
                ? Colors.white
                : theme.primaryColor,
          ),
        ),
      );
    }

    final buttonText = Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: _getTextColor(theme),
      ),
    );

    if (icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: _getTextColor(theme)),
          const SizedBox(width: 8),
          buttonText,
        ],
      );
    }

    return buttonText;
  }

  Color _getTextColor(ThemeData theme) {
    if (textColor != null) return textColor!;
    
    switch (variant) {
      case SCompassButtonVariant.outlined:
      case SCompassButtonVariant.text:
        return backgroundColor ?? theme.primaryColor;
      case SCompassButtonVariant.filled:
        return Colors.white;
    }
  }
}

class SCompassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;
  final String? tooltip;

  const SCompassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 24,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: size),
      onPressed: onPressed,
      color: color ?? Theme.of(context).primaryColor,
      tooltip: tooltip,
      splashRadius: 24,
    );
  }
}

class SCompassFloatingActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? iconColor;

  const SCompassFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
      child: Icon(
        icon,
        color: iconColor ?? Colors.white,
      ),
    );
  }
}
