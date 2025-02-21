import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/forum_home_screen.dart';
import '../screens/forum_chat_screen.dart';
import '../screens/forum_create_screen.dart';
import '../screens/forum_settings_screen.dart';
import '../screens/forum_members_screen.dart';
import '../screens/forum_profile_screen.dart';

class ForumRoutes {
  static const String forums = '/forums';
  static const String createForum = '/forums/create';  
  static const String forumChat = '/forums/:forumId';
  static const String forumSettings = '/forums/:forumId/settings';
  static const String forumMembers = '/forums/:forumId/members';
  static const String forumProfile = '/forums/:forumId/profile';

  static List<RouteBase> get routes => [
        GoRoute(
          path: forums,
          builder: (context, state) => const ForumHomeScreen(),
        ),
        GoRoute(
          path: createForum,  
          builder: (context, state) => const ForumCreateScreen(),
        ),
        GoRoute(
          path: forumChat,
          builder: (context, state) => ForumChatScreen(
            forumId: state.pathParameters['forumId']!,
          ),
        ),
        GoRoute(
          path: forumSettings,
          builder: (context, state) => ForumSettingsScreen(
            forumId: state.pathParameters['forumId']!,
          ),
        ),
        GoRoute(
          path: forumMembers,
          builder: (context, state) => ForumMemberScreen(
            forumId: state.pathParameters['forumId']!,
          ),
        ),
        GoRoute(
          path: forumProfile,
          builder: (context, state) => ForumProfileScreen(
            forumId: state.pathParameters['forumId']!,
          ),
        ),
      ];
}
