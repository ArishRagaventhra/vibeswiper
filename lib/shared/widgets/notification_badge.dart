import 'package:flutter/material.dart';
import 'package:scompass_07/config/theme.dart';

class NotificationBadge extends StatelessWidget {
  final int count;
  final Color? color;
  final double size;

  const NotificationBadge({
    super.key,
    required this.count,
    this.color,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.error,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      constraints: BoxConstraints(
        minWidth: size,
        minHeight: size,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onError,
            fontSize: size * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
