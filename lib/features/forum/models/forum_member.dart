class ForumMember {
  final String forumId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  final DateTime lastReadAt;
  final bool isMuted;
  final Map<String, dynamic> notificationPreferences;

  ForumMember({
    required this.forumId,
    required this.userId,
    required this.role,
    required this.joinedAt,
    required this.lastReadAt,
    required this.isMuted,
    required this.notificationPreferences,
  });

  Map<String, dynamic> toJson() {
    return {
      'forum_id': forumId,
      'user_id': userId,
      'role': role,
      'joined_at': joinedAt.toIso8601String(),
      'last_read_at': lastReadAt.toIso8601String(),
      'is_muted': isMuted,
      'notification_preferences': notificationPreferences,
    };
  }

  factory ForumMember.fromJson(Map<String, dynamic> json) {
    return ForumMember(
      forumId: json['forum_id'],
      userId: json['user_id'],
      role: json['role'],
      joinedAt: DateTime.parse(json['joined_at']),
      lastReadAt: DateTime.parse(json['last_read_at']),
      isMuted: json['is_muted'] ?? false,
      notificationPreferences: json['notification_preferences'] ?? {},
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderator';
  bool get isMember => role == 'member';
}
