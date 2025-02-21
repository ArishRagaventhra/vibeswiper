import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/features/notifications/models/notification_item.dart';
import 'package:scompass_07/features/notifications/services/notifications_service.dart';

class NotificationsState {
  final List<NotificationItem> notifications;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<NotificationItem>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsService _service;
  StreamSubscription? _subscription;

  NotificationsNotifier(this._service) : super(const NotificationsState()) {
    fetchNotifications();
    listenToNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final notifications = await _service.fetchNotifications();
      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _service.markAsRead(notificationId);
      state = state.copyWith(
        notifications: state.notifications.map((notification) {
          if (notification.id == notificationId) {
            return notification.copyWith(isRead: true);
          }
          return notification;
        }).toList(),
      );
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _service.markAllAsRead();
      state = state.copyWith(
        notifications: state.notifications
            .map((notification) => notification.copyWith(isRead: true))
            .toList(),
      );
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _service.deleteNotification(notificationId);
      state = state.copyWith(
        notifications: state.notifications
            .where((notification) => notification.id != notificationId)
            .toList(),
      );
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      await _service.clearAllNotifications();
      state = state.copyWith(notifications: []);
    } catch (e) {
      debugPrint('Error clearing all notifications: $e');
    }
  }

  void listenToNotifications() {
    _subscription = _service.onNotification.listen((notification) {
      state = state.copyWith(
        notifications: [notification, ...state.notifications],
      );
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(NotificationsService());
});
