import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/features/auth/screens/login_screen.dart';
import 'package:scompass_07/features/auth/screens/register_screen.dart';
import 'package:scompass_07/features/auth/screens/forgot_password_screen.dart';
import 'package:scompass_07/features/profile/screens/profile_screen.dart';
import 'package:scompass_07/features/profile/screens/edit_profile_screen.dart';
import 'package:scompass_07/features/notifications/screens/notifications_screen.dart';
import 'package:scompass_07/features/events/screens/create_event_screen.dart';
import 'package:scompass_07/features/events/screens/events_list_screen.dart';
import 'package:scompass_07/features/events/screens/event_details_screen.dart';
import 'package:scompass_07/features/events/screens/edit_event_screen.dart';
import 'package:scompass_07/features/events/chat/screens/event_chat_screen.dart';
import 'package:scompass_07/features/events/screens/my_events_screen.dart';
import 'package:scompass_07/features/events/screens/event_participants_screen.dart';
import 'package:scompass_07/features/events/screens/event_responses_dashboard.dart';
import 'package:scompass_07/features/events/screens/event_organizer_dashboard.dart';
import 'package:scompass_07/features/profile/providers/profile_provider.dart';
import 'package:scompass_07/features/forum/routes/forum_routes.dart';
import '../features/account/screens/account_screen.dart';
import '../features/settings/screens/privacy_policy_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/terms_conditions_screen.dart';
import '../features/payments/screens/payment_history_screen.dart';
import '../features/events/screens/event_search_screen.dart';

class NoTransitionPage<T> extends CustomTransitionPage<T> {
  NoTransitionPage({
    required Widget child,
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
  }) : super(
    child: child,
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    transitionsBuilder: (_, __, ___, child) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

class AppRoutes {
  static final supabase = SupabaseConfig.client;
  static const String login = '/';  
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String editProfile = '/profile/edit';
  static const String profile = '/profile/:userId';
  static const String eventsList = '/events';
  static const String eventDetails = '/events/:eventId';
  static const String eventChat = '/events/:eventId/chat';
  static const String eventParticipants = '/events/:eventId/participants';
  static const String eventResponses = '/events/:eventId/responses';
  static const String eventDashboard = '/events/:eventId/dashboard';
  static const String editEvent = '/events/:eventId/edit';
  static const String createEvent = '/events/create';
  static const String eventSearch = '/events/search';
  static const String myEvents = '/my-events';
  static const String notifications = '/notifications';
  static const String account = '/account';
  static const String settings = '/settings';
  static const String privacyPolicy = '/settings/privacy-policy';
  static const String termsConditions = '/settings/terms-conditions';
  static const String paymentHistory = '/payments/history';

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router(WidgetRef ref) => GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: login,  
    routes: [
      GoRoute(
        path: login,
        pageBuilder: (context, state) => NoTransitionPage(
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: register,
        pageBuilder: (context, state) => NoTransitionPage(
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: forgotPassword,
        pageBuilder: (context, state) => NoTransitionPage(
          child: const ForgotPasswordScreen(),
        ),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: eventsList,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const EventsListScreen(),
            ),
          ),
          GoRoute(
            path: eventSearch,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const EventSearchScreen(),
            ),
          ),
          GoRoute(
            path: myEvents,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const MyEventsScreen(),
            ),
          ),
          GoRoute(
            path: createEvent,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const CreateEventScreen(),
            ),
          ),
          GoRoute(
            path: eventDetails,
            name: 'event-details',  
            pageBuilder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return NoTransitionPage(
                child: EventDetailsScreen(eventId: eventId),
              );
            },
          ),
          GoRoute(
            path: eventChat,
            pageBuilder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return NoTransitionPage(
                child: EventChatScreen(eventId: eventId),
              );
            },
          ),
          GoRoute(
            path: eventParticipants,
            pageBuilder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return NoTransitionPage(
                child: EventParticipantsScreen(eventId: eventId),
              );
            },
          ),
          GoRoute(
            path: eventResponses,
            pageBuilder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return NoTransitionPage(
                child: EventResponsesDashboard(eventId: eventId),
              );
            },
          ),
          GoRoute(
            path: eventDashboard,
            pageBuilder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return NoTransitionPage(
                child: EventOrganizerDashboard(eventId: eventId),
              );
            },
          ),
          GoRoute(
            path: editEvent,
            pageBuilder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return NoTransitionPage(
                child: EditEventScreen(eventId: eventId),
              );
            },
          ),
          GoRoute(
            path: notifications,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: editProfile,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const EditProfileScreen(),
            ),
          ),
          GoRoute(
            path: profile,
            pageBuilder: (context, state) {
              final userId = state.pathParameters['userId']!;
              return NoTransitionPage(
                child: ProfileScreen(userId: userId),
              );
            },
          ),
          ...ForumRoutes.routes,
          GoRoute(
            path: account,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const AccountScreen(),
            ),
          ),
          GoRoute(
            path: settings,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: privacyPolicy,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const PrivacyPolicyScreen(),
            ),
          ),
          GoRoute(
            path: termsConditions,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const TermsConditionsScreen(),
            ),
          ),
          // Removed notification settings route
          GoRoute(
            path: paymentHistory,
            pageBuilder: (context, state) => NoTransitionPage(
              child: const PaymentHistoryScreen(),
            ),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentUser != null;
      final isGoingToAuth = state.matchedLocation == login ||
          state.matchedLocation == register ||
          state.matchedLocation == forgotPassword;

      if (!isLoggedIn && !isGoingToAuth) {
        return login;
      }
      if (isLoggedIn && isGoingToAuth) {
        return eventsList;  
      }
      return null;
    },
    errorBuilder: (context, state) => const ErrorScreen(),
  );
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Error: Page not found!'),
      ),
    );
  }
}
