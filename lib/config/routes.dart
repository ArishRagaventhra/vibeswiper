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
import 'package:scompass_07/features/events/screens/event_payment_screen.dart';
import 'package:scompass_07/features/events/screens/event_booking_screen.dart';
import 'package:scompass_07/features/events/chat/screens/event_chat_screen.dart';
import 'package:scompass_07/features/events/screens/my_events_screen.dart';
import 'package:scompass_07/features/events/screens/event_participants_screen.dart';
import 'package:scompass_07/features/events/screens/event_responses_dashboard.dart';
import 'package:scompass_07/features/events/screens/event_organizer_dashboard.dart';
import 'package:scompass_07/features/events/chat/screens/payment_analytics_screen.dart';
import 'package:scompass_07/features/profile/providers/profile_provider.dart';
import 'package:scompass_07/features/forum/routes/forum_routes.dart';
import '../features/account/screens/account_screen.dart';
import '../features/settings/screens/privacy_policy_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/settings/screens/terms_conditions_screen.dart';
import '../features/payments/screens/payment_history_screen.dart';
import '../features/events/screens/event_search_screen.dart';
import '../screens/fcm_debug_screen.dart';
import '../features/events/screens/booking_history_screen.dart';
import '../features/events/screens/booking_details_screen.dart';
import '../features/events/screens/ticket_scanner_screen.dart';
import '../services/deep_link_service.dart';
import '../blogs/config/blog_routes.dart';

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
  static const String eventPayment = '/events/:eventId/payment';
  static const String eventBooking = '/events/:eventId/booking';
  static const String fcmDebug = '/fcm-debug';
  static const String paymentHistory = '/payment-history';
  static const String bookingHistory = '/booking-history';
  static const String bookingDetails = '/booking/:id';
  static const String ticketScanner = '/events/:eventId/ticket-scanner';
  static const String paymentAnalytics = '/events/:eventId/payment-analytics';
  
  // Helper method to generate shareable URI
  static String generateShareableUri(String path) {
    // Remove leading slash if present for URI format
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    
    // Ensure path is properly formatted with a leading slash
    final formattedPath = path.isEmpty ? '' : '/$path';
    
    // Debug the generated URL
    debugPrint('Generating shareable URI with path: $path, formatted: $formattedPath');
    
    // For local testing
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      final url = 'http://localhost:59727/#$path';
      debugPrint('Generated local testing URL: $url');
      return url;
    }
    
    // Production URL
    final url = 'https://vibeswiper.scompasshub.com$formattedPath';
    debugPrint('Generated production URL: $url');
    return url;
  }
  
  // Helper methods for common screens
  static String getEventDetailsUri(String eventId) {
    final path = '/events/$eventId';
    return generateShareableUri(path);
  }
  
  static String getProfileUri(String userId) {
    final path = '/profile/$userId';
    return generateShareableUri(path);
  }

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router(WidgetRef ref) => GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: eventsList,
    debugLogDiagnostics: true,
    routerNeglect: false,  // Enable URL updates during navigation
    
    redirect: (context, state) async {
      debugPrint('Router handling location: ${state.uri}');
      
      // Special handling for deep links from various sources
      if (state.uri.scheme == 'vibeswiper' || 
          state.uri.host == 'vibeswiper.scompasshub.com') {
          
        final pathSegments = state.uri.pathSegments;
        debugPrint('Deep link path segments: $pathSegments');
        
        // Handle event deep links 
        if (pathSegments.isNotEmpty && pathSegments[0] == 'events' && pathSegments.length >= 2) {
          final eventId = pathSegments[1];
          debugPrint('Deep link routing to event: $eventId');
          return '/events/$eventId';
        }
        
        // Handle booking history deep link
        if (pathSegments.isNotEmpty && pathSegments[0] == 'booking-history') {
          debugPrint('Deep link routing to booking history');
          return '/booking-history';
        }
        
        // Handle booking details deep link
        if (pathSegments.length >= 2 && pathSegments[0] == 'booking') {
          final bookingId = pathSegments[1];
          debugPrint('Deep link routing to booking: $bookingId');
          return '/booking/$bookingId';
        }
      }
      
      // Handle authentication redirects
      final isAuth = supabase.auth.currentUser != null;
      final isAuthRoute = state.matchedLocation == login || 
                         state.matchedLocation == register ||
                         state.matchedLocation == forgotPassword;

      if (!isAuth && !isAuthRoute) {
        return login;
      } else if (isAuth && isAuthRoute) {
        return eventsList;
      }
      return null;
    },
    errorBuilder: (context, state) => ErrorScreen(
      error: state.error.toString(),
    ),
    routes: [
      GoRoute(
        path: login,
        pageBuilder: (context, state) => NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: register,
        pageBuilder: (context, state) => NoTransitionPage(
          child: RegisterScreen(),
        ),
      ),
      GoRoute(
        path: forgotPassword,
        pageBuilder: (context, state) => NoTransitionPage(
          child: ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: eventsList,
        pageBuilder: (context, state) => NoTransitionPage(
          child: EventsListScreen(),
        ),
      ),
      GoRoute(
        path: createEvent,
        name: 'create-event',
        pageBuilder: (context, state) => NoTransitionPage(
          child: CreateEventScreen(),
        ),
      ),
      GoRoute(
        path: eventSearch,
        name: 'event-search',
        pageBuilder: (context, state) => NoTransitionPage(
          child: EventSearchScreen(),
        ),
      ),
      GoRoute(
        path: paymentHistory,
        name: 'payment-history',
        pageBuilder: (context, state) => NoTransitionPage(
          child: PaymentHistoryScreen(),
        ),
      ),
      GoRoute(
        path: fcmDebug,
        name: 'fcm-debug',
        pageBuilder: (context, state) => NoTransitionPage(
          child: const FCMDebugScreen(),
        ),
      ),
      // Payment route must come before generic event route
      GoRoute(
        path: eventPayment,
        name: 'event-payment',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return NoTransitionPage(
            child: EventPaymentScreen(
              eventId: extra['eventId'] as String,
              eventName: extra['eventName'] as String,
              onPaymentSuccess: extra['onPaymentSuccess'] as VoidCallback,
            ),
          );
        },
      ),
      GoRoute(
        path: '/events/:eventId',
        name: 'event-details',
        pageBuilder: (context, state) {
          final eventId = state.pathParameters['eventId'];
          return NoTransitionPage(
            child: EventDetailsScreen(eventId: eventId!),
          );
        },
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: myEvents,
            pageBuilder: (context, state) => NoTransitionPage(
              child: MyEventsScreen(),
            ),
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
            path: ticketScanner,
            pageBuilder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              return NoTransitionPage(
                child: TicketScannerScreen(eventId: eventId),
              );
            },
          ),
          GoRoute(
            path: paymentAnalytics,
            pageBuilder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              final eventName = state.extra as String? ?? 'Event';
              return NoTransitionPage(
                child: PaymentAnalyticsScreen(
                  eventId: eventId,
                  eventName: eventName,
                ),
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
            path: eventBooking,
            pageBuilder: (context, state) {
              final eventId = state.pathParameters['eventId']!;
              final event = state.extra as Map<String, dynamic>?;
              return NoTransitionPage(
                child: EventBookingScreen(
                  eventId: eventId,
                  event: event?['event'],
                ),
              );
            },
          ),
          GoRoute(
            path: notifications,
            pageBuilder: (context, state) => NoTransitionPage(
              child: NotificationsScreen(),
            ),
          ),
          GoRoute(
            path: editProfile,
            pageBuilder: (context, state) => NoTransitionPage(
              child: EditProfileScreen(),
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
          ...BlogRoutes.getRoutes(),
          GoRoute(
            path: account,
            pageBuilder: (context, state) => NoTransitionPage(
              child: AccountScreen(),
            ),
          ),
          GoRoute(
            path: settings,
            pageBuilder: (context, state) => NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
          GoRoute(
            path: privacyPolicy,
            pageBuilder: (context, state) => NoTransitionPage(
              child: PrivacyPolicyScreen(),
            ),
          ),
          GoRoute(
            path: termsConditions,
            pageBuilder: (context, state) => NoTransitionPage(
              child: TermsConditionsScreen(),
            ),
          ),
          // Removed notification settings route
          GoRoute(
            path: paymentHistory,
            pageBuilder: (context, state) => NoTransitionPage(
              child: PaymentHistoryScreen(),
            ),
          ),
          GoRoute(
            path: bookingHistory,
            pageBuilder: (context, state) => NoTransitionPage(
              child: BookingHistoryScreen(),
            ),
          ),
          GoRoute(
            path: bookingDetails,
            pageBuilder: (context, state) {
              final bookingId = state.pathParameters['id']!;
              return NoTransitionPage(
                child: BookingDetailsScreen(bookingId: bookingId),
              );
            },
          ),
        ],
      ),
    ],
  );

  // Create a static method that can accept a ProviderRef instead of WidgetRef
  static GoRouter createRouter(ProviderRef<GoRouter> ref) {
    // Reuse the same logic but handle the different ref type
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: eventsList,
      debugLogDiagnostics: true,
      routerNeglect: false,  // Enable URL updates during navigation
      
      redirect: (context, state) async {
        // Special handling for deep links
        if (state.uri.scheme == 'vibeswiper') {
          final pathSegments = state.uri.pathSegments;
          
          // Handle event deep links 
          if (pathSegments.length >= 2 && pathSegments[0] == 'events') {
            final eventId = pathSegments[1];
            return '/events/$eventId';
          }
        }
        
        // Handle authentication redirects
        final isAuth = supabase.auth.currentUser != null;
        final isAuthRoute = state.matchedLocation == login || 
                           state.matchedLocation == register ||
                           state.matchedLocation == forgotPassword;

        if (!isAuth && !isAuthRoute) {
          return login;
        } else if (isAuth && isAuthRoute) {
          return eventsList;
        }
        return null;
      },
      errorBuilder: (context, state) => ErrorScreen(
        error: state.error.toString(),
      ),
      routes: [
        GoRoute(
          path: login,
          pageBuilder: (context, state) => NoTransitionPage(
            child: LoginScreen(),
          ),
        ),
        GoRoute(
          path: register,
          pageBuilder: (context, state) => NoTransitionPage(
            child: RegisterScreen(),
          ),
        ),
        GoRoute(
          path: forgotPassword,
          pageBuilder: (context, state) => NoTransitionPage(
            child: ForgotPasswordScreen(),
          ),
        ),
        GoRoute(
          path: eventsList,
          pageBuilder: (context, state) => NoTransitionPage(
            child: EventsListScreen(),
          ),
        ),
        GoRoute(
          path: createEvent,
          name: 'create-event',
          pageBuilder: (context, state) => NoTransitionPage(
            child: CreateEventScreen(),
          ),
        ),
        GoRoute(
          path: eventSearch,
          name: 'event-search',
          pageBuilder: (context, state) => NoTransitionPage(
            child: EventSearchScreen(),
          ),
        ),
        GoRoute(
          path: paymentHistory,
          name: 'payment-history',
          pageBuilder: (context, state) => NoTransitionPage(
            child: PaymentHistoryScreen(),
          ),
        ),
        GoRoute(
          path: fcmDebug,
          name: 'fcm-debug',
          pageBuilder: (context, state) => NoTransitionPage(
            child: const FCMDebugScreen(),
          ),
        ),
        // Payment route must come before generic event route
        GoRoute(
          path: eventPayment,
          name: 'event-payment',
          pageBuilder: (context, state) {
            final extra = state.extra as Map<String, dynamic>;
            return NoTransitionPage(
              child: EventPaymentScreen(
                eventId: extra['eventId'] as String,
                eventName: extra['eventName'] as String,
                onPaymentSuccess: extra['onPaymentSuccess'] as VoidCallback,
              ),
            );
          },
        ),
        GoRoute(
          path: '/events/:eventId',
          name: 'event-details',
          pageBuilder: (context, state) {
            final eventId = state.pathParameters['eventId'];
            return NoTransitionPage(
              child: EventDetailsScreen(eventId: eventId!),
            );
          },
        ),
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => child,
          routes: [
            GoRoute(
              path: myEvents,
              pageBuilder: (context, state) => NoTransitionPage(
                child: MyEventsScreen(),
              ),
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
              path: ticketScanner,
              pageBuilder: (context, state) {
                final eventId = state.pathParameters['eventId']!;
                return NoTransitionPage(
                  child: TicketScannerScreen(eventId: eventId),
                );
              },
            ),
            GoRoute(
              path: paymentAnalytics,
              pageBuilder: (context, state) {
                final eventId = state.pathParameters['eventId']!;
                final eventName = state.extra as String? ?? 'Event';
                return NoTransitionPage(
                  child: PaymentAnalyticsScreen(
                    eventId: eventId,
                    eventName: eventName,
                  ),
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
              path: eventBooking,
              pageBuilder: (context, state) {
                final eventId = state.pathParameters['eventId']!;
                final event = state.extra as Map<String, dynamic>?;
                return NoTransitionPage(
                  child: EventBookingScreen(
                    eventId: eventId,
                    event: event?['event'],
                  ),
                );
              },
            ),
            GoRoute(
              path: notifications,
              pageBuilder: (context, state) => NoTransitionPage(
                child: NotificationsScreen(),
              ),
            ),
            GoRoute(
              path: editProfile,
              pageBuilder: (context, state) => NoTransitionPage(
                child: EditProfileScreen(),
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
            ...BlogRoutes.getRoutes(),
            GoRoute(
              path: account,
              pageBuilder: (context, state) => NoTransitionPage(
                child: AccountScreen(),
              ),
            ),
            GoRoute(
              path: settings,
              pageBuilder: (context, state) => NoTransitionPage(
                child: SettingsScreen(),
              ),
            ),
            GoRoute(
              path: privacyPolicy,
              pageBuilder: (context, state) => NoTransitionPage(
                child: PrivacyPolicyScreen(),
              ),
            ),
            GoRoute(
              path: termsConditions,
              pageBuilder: (context, state) => NoTransitionPage(
                child: TermsConditionsScreen(),
              ),
            ),
            // Removed notification settings route
            GoRoute(
              path: paymentHistory,
              pageBuilder: (context, state) => NoTransitionPage(
                child: PaymentHistoryScreen(),
              ),
            ),
            GoRoute(
              path: bookingHistory,
              pageBuilder: (context, state) => NoTransitionPage(
                child: BookingHistoryScreen(),
              ),
            ),
            GoRoute(
              path: bookingDetails,
              pageBuilder: (context, state) {
                final bookingId = state.pathParameters['id']!;
                return NoTransitionPage(
                  child: BookingDetailsScreen(bookingId: bookingId),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

// Create a provider for the router
final routerProvider = Provider<GoRouter>((ref) {
  return AppRoutes.createRouter(ref);
});

// Create a provider for the DeepLinkService that depends on the router
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final router = ref.watch(routerProvider);
  return DeepLinkService(router: router);
});

class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Error: $error'),
      ),
    );
  }
}
