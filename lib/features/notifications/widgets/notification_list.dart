import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/features/notifications/providers/notifications_provider.dart';
import 'package:scompass_07/features/notifications/widgets/notification_card.dart';

class NotificationList extends ConsumerWidget {
  const NotificationList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationsProvider);

    if (notificationsState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (notificationsState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              notificationsState.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(notificationsProvider.notifier).fetchNotifications();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (notificationsState.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you receive notifications, they will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(notificationsProvider.notifier).fetchNotifications();
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: notificationsState.notifications.length,
        itemBuilder: (context, index) {
          final notification = notificationsState.notifications[index];
          return NotificationCard(
            key: ValueKey(notification.id),
            notification: notification,
            onTap: () {
              ref.read(notificationsProvider.notifier).markAsRead(notification.id);
              // Handle notification tap
              if (notification.actionUrl != null) {
                // Navigate to action URL
              }
            },
            onDismiss: () {
              ref.read(notificationsProvider.notifier).deleteNotification(notification.id);
            },
          );
        },
      ),
    );
  }
}
