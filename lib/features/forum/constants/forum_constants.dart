class ForumConstants {
  static const String tableForum = 'forums';
  static const String tableForumMembers = 'forum_members';
  static const String tableForumMessages = 'forum_messages';
  static const String tableForumMessageMedia = 'forum_message_media';
  static const String tableForumReports = 'forum_reports';

  // Storage Buckets
  static const String forumMediaBucket = 'forum-media';
  static const String forumImagesBucket = 'forum-images';

  // Storage Paths - Using consistent naming with buckets
  static const String forumProfileImagePath = 'profile';
  static const String forumBannerImagePath = 'banner';
  static const String forumMessageMediaPath = 'messages';

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleModerator = 'moderator';
  static const String roleMember = 'member';

  // Message Types
  static const String messageTypeText = 'text';
  static const String messageTypeMedia = 'media';
  static const String messageTypeSystem = 'system';

  // Media Types
  static const String mediaTypeImage = 'image';
  static const String mediaTypeVideo = 'video';
  static const String mediaTypeDocument = 'document';
  static const String mediaTypeAudio = 'audio';

  // Message States
  static const String messageStateNormal = 'normal';
  static const String messageStateDeleted = 'deleted';
  static const String messageStateEdited = 'edited';
  static const String messageStatePinned = 'pinned';
  static const String messageStateAnnouncement = 'announcement';

  // Forum Member States
  static const String memberStateActive = 'active';
  static const String memberStateBlocked = 'blocked';
  static const String memberStateMuted = 'muted';
  static const String memberStateLeft = 'left';
  static const String memberStateKicked = 'kicked';
  static const String memberStateBanned = 'banned';

  // Forum Privacy Types
  static const String forumPrivacyPublic = 'public';
  static const String forumPrivacyPrivate = 'private';
  static const String forumPrivacySecret = 'secret';

  // Forum Join Types
  static const String forumJoinOpen = 'open';
  static const String forumJoinRequest = 'request';
  static const String forumJoinInvite = 'invite';

  // Default Settings
  static const Map<String, dynamic> defaultForumSettings = {
    'allow_media': true,
    'allow_reactions': true,
    'allow_message_editing': true,
    'allow_message_deletion': true,
    'message_retention_days': 365,
    'banned_words': [],
  };

  static const Map<String, dynamic> defaultNotificationPreferences = {
    'all_messages': true,
    'mentions': true,
    'announcements': true,
  };

  // Validation Constants
  static const int minForumNameLength = 3;
  static const int maxForumNameLength = 100;
  static const int maxMessageLength = 5000;
  static const int maxReportReasonLength = 1000;

  // Report Status
  static const String reportStatusPending = 'pending';
  static const String reportStatusResolved = 'resolved';
  static const String reportStatusDismissed = 'dismissed';
}
