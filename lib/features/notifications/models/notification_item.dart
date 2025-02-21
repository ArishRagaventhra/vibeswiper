import 'package:flutter/material.dart';

enum NotificationType {
  event(
    icon: Icons.event,
    color: Colors.blue,
  ),
  community(
    icon: Icons.group,
    color: Colors.green,
  ),
  message(
    icon: Icons.message,
    color: Colors.orange,
  ),
  alert(
    icon: Icons.notifications,
    color: Colors.red,
  );

  final IconData icon;
  final Color color;

  const NotificationType({
    required this.icon,
    required this.color,
  });
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final NotificationType type;
  final bool isRead;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;
  final String? category;
  final int priority;
  final String? senderAvatarUrl;
  final String? senderId;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.isRead = false,
    this.actionUrl,
    this.metadata,
    this.category,
    this.priority = 0,
    this.senderAvatarUrl,
    this.senderId,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      time: DateTime.parse(json['created_at'] as String),
      type: NotificationType.values.firstWhere(
        (type) => type.name == (json['type'] as String? ?? 'alert'),
        orElse: () => NotificationType.alert,
      ),
      isRead: json['is_read'] as bool? ?? false,
      actionUrl: json['link'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      category: json['category'] as String?,
      priority: json['priority'] as int? ?? 0,
      senderAvatarUrl: json['sender_avatar_url'] as String?,
      senderId: json['sender_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'created_at': time.toIso8601String(),
    'type': type.name,
    'is_read': isRead,
    'link': actionUrl,
    'metadata': metadata,
    'category': category,
    'priority': priority,
    'sender_avatar_url': senderAvatarUrl,
    'sender_id': senderId,
  };

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? time,
    NotificationType? type,
    bool? isRead,
    String? actionUrl,
    Map<String, dynamic>? metadata,
    String? category,
    int? priority,
    String? senderAvatarUrl,
    String? senderId,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      time: time ?? this.time,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      senderId: senderId ?? this.senderId,
    );
  }

  @override
  String toString() {
    return 'NotificationItem(id: $id, title: $title, message: $message, time: $time, type: ${type.name}, isRead: $isRead, actionUrl: $actionUrl, category: $category, priority: $priority, senderAvatarUrl: $senderAvatarUrl, senderId: $senderId)';
  }
}
