import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/features/notifications/providers/notifications_provider.dart';

class NotificationBadge extends ConsumerWidget {
  final Widget child;
  final double? top;
  final double? right;
  final double size;
  final Color? color;

  const NotificationBadge({
    Key? key,
    required this.child,
    this.top = -5,
    this.right = -5,
    this.size = 16,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider).notifications;
    final unreadCount = notifications.where((n) => !n.isRead).length;

    if (unreadCount == 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: top,
          right: right,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: color ?? Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            constraints: BoxConstraints(
              minWidth: size,
              minHeight: size,
            ),
            child: Center(
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
