// Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

// Third-party package imports
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Local imports - Models
import '../models/event_model.dart';
import '../models/event_participant_model.dart';
import '../models/event_action_model.dart';

// Local imports - Controllers
import '../controllers/event_controller.dart';
import '../controllers/event_participant_controller.dart';

// Local imports - Providers
import '../providers/event_providers.dart';

// Local imports - Widgets
import '../../../config/theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../repositories/event_response_repository.dart';
import '../widgets/access_code_bottom_sheet.dart';
import '../widgets/event_action_dialog.dart';
import '../widgets/event_join_requirements_dialog.dart';
import 'package:scompass_07/core/widgets/edge_to_edge_container.dart';
import '../../../core/utils/responsive_layout.dart';
import '../widgets/event_details_instructions_overlay.dart';
import '../../../shared/widgets/avatar.dart';
import '../widgets/event_about_section.dart';
import '../widgets/event_location_section.dart';
import '../widgets/event_visibility_section.dart';
import '../widgets/event_datetime_section.dart';
import '../widgets/event_participants_section.dart';
import '../widgets/event_policy_section.dart';
import '../../../config/routes.dart';
import '../utils/recurring_event_utils.dart';

class EventDetailsScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailsScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  ConsumerState<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends ConsumerState<EventDetailsScreen> {
  final _scrollController = ScrollController();
  final _pageController = PageController();
  int _currentImageIndex = 0;
  late Future<void> _eventFuture;
  bool _showInstructions = false;

  // Variables to control Vibe Price reveal animation
  bool _vibePriceRevealed = false;
  final _vibePriceAnimationDuration = const Duration(milliseconds: 800);
  
  void _revealVibePrice() {
    setState(() {
      _vibePriceRevealed = true;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
    _checkFirstTimeUser();
  }

  Future<void> _checkFirstTimeUser() async {
    final shouldShow = await EventDetailsInstructions.shouldShowInstructions();
    if (mounted && shouldShow) {
      setState(() {
        _showInstructions = true;
      });
    }
  }

  void _dismissInstructions() {
    EventDetailsInstructions.markInstructionsAsSeen();
    setState(() {
      _showInstructions = false;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadEventDetails() async {
    final eventId = widget.eventId;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    debugPrint('Loading event details for event ID: $eventId');
    
    try {
      // Load event details
      ref.read(eventDetailsProvider(eventId));
      
      // Load participants using Future.microtask
      Future.microtask(() async {
        await ref.read(eventParticipantControllerProvider.notifier).loadParticipants(eventId);
      });
      
      // Check participation status
      final participationStatus = await ref.read(userParticipationProvider((
        eventId: eventId,
        userId: currentUser.id,
      )));
      
      debugPrint('Initial participation status for user ${currentUser.id}: $participationStatus');
    } catch (e) {
      debugPrint('Error loading event details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));
    final currentUser = ref.watch(currentUserProvider);
    final userParticipationAsync = currentUser != null
        ? ref.watch(userParticipationProvider((
            eventId: widget.eventId,
            userId: currentUser.id,
          )))
        : null;
    
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarColor = isDark ? AppTheme.darkBackgroundColor : Colors.white;
    final foregroundColor = isDark ? AppTheme.darkPrimaryTextColor : AppTheme.primaryTextColor;
    
    // Determine screen size category for responsive design
    final isLargeScreen = ResponsiveLayout.isDesktop(context);
    final isMediumScreen = ResponsiveLayout.isTablet(context);
    final isSmallScreen = ResponsiveLayout.isMobile(context);
    final contentMaxWidth = ResponsiveLayout.getContentMaxWidth(context);
    
    // Calculate responsive dimensions
    final imageHeight = isLargeScreen 
        ? size.height * 0.4 
        : isMediumScreen 
            ? size.height * 0.35 
            : size.height * 0.45;
    
    // Reduced width for larger screens to make it less horizontally extensive
    final imageWidth = isLargeScreen
        ? size.width * 0.4 // Significantly reduced width for desktop
        : isMediumScreen
            ? size.width * 0.55 // Reduced width for tablet
            : size.width * 0.85; // Keep mobile size the same
    
    return EdgeToEdgeContainer(
      statusBarColor: Colors.transparent,
      navigationBarColor: Theme.of(context).colorScheme.background,
      statusBarIconBrightness: Brightness.light,
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: eventAsync.when(
          data: (event) {
            if (event == null) return const Center(child: Text('Event not found'));

            // Debug: Print creator check info
            debugPrint('Current user ID: ${currentUser?.id}');
            debugPrint('Event creator ID: ${event.creatorId}');
            final isCreator = currentUser != null && event.creatorId == currentUser.id;
            debugPrint('Is creator: $isCreator');

            return Stack(
              children: [
                // Scrollable Content
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Enhanced App Bar with Frosted Glass Effect
                    SliverAppBar(
                      expandedHeight: 60,
                      floating: true,
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      flexibleSpace: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: appBarColor.withOpacity(0.7),
                          ),
                        ),
                      ),
                      leading: Container(
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: foregroundColor,
                            size: 18,
                          ),
                          onPressed: () => context.go('/events'),
                        ),
                      ),
                      actions: [
                        if (isCreator)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.7),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.assessment_outlined,
                                size: 20,
                              ),
                              tooltip: 'Event Dashboard',
                              onPressed: () => context.push('/events/${event.id}/dashboard'),
                            ),
                          ),
                        Container(
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.ios_share_rounded,
                              color: foregroundColor,
                              size: 20,
                            ),
                            onPressed: () => _shareEvent(event),
                          ),
                        ),
                      ],
                    ),
                    
                    // Enhanced Image Section with Parallax Effect and QR Code
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: isLargeScreen || isMediumScreen ? size.width * 0.05 : size.width * 0.05,
                          right: isLargeScreen || isMediumScreen ? size.width * 0.05 : size.width * 0.05,
                          top: 16,
                          bottom: 16,
                        ),
                        child: Row(  // Row with image and slightly offset QR code
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: isSmallScreen ? MainAxisAlignment.center : MainAxisAlignment.start,
                          children: [
                            // Event Image Container
                            Container(
                              height: imageHeight,
                              width: imageWidth,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Stack(
                              children: [
                                // Image Carousel with Parallax Effect
                                if (event.mediaUrls != null && event.mediaUrls!.isNotEmpty)
                                  GestureDetector(
                                    onHorizontalDragEnd: (details) {
                                      if (details.primaryVelocity! > 0) {
                                        // Swipe right - go to previous page
                                        if (_currentImageIndex > 0) {
                                          _pageController.previousPage(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      } else if (details.primaryVelocity! < 0) {
                                        // Swipe left - go to next page
                                        if (_currentImageIndex < event.mediaUrls!.length - 1) {
                                          _pageController.nextPage(
                                            duration: const Duration(milliseconds: 300),
                                            curve: Curves.easeInOut,
                                          );
                                        }
                                      }
                                    },
                                    child: Stack(
                                      children: [
                                        PageView.builder(
                                          controller: _pageController,
                                          physics: const BouncingScrollPhysics(),
                                          onPageChanged: (index) {
                                            setState(() {
                                              _currentImageIndex = index;
                                            });
                                          },
                                          itemCount: event.mediaUrls!.length,
                                          itemBuilder: (context, index) {
                                            return ShaderMask(
                                              shaderCallback: (rect) {
                                                return LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(0.5),
                                                  ],
                                                  stops: const [0.7, 1.0],
                                                ).createShader(rect);
                                              },
                                              blendMode: BlendMode.darken,
                                              child: Image.network(
                                                event.mediaUrls![index],
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Center(
                                                    child: Icon(
                                                      Icons.error_outline,
                                                      size: 48,
                                                      color: theme.colorScheme.error,
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                        
                                        // Left and right navigation buttons for manual control
                                        if (event.mediaUrls!.length > 1)
                                        Positioned.fill(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              // Left arrow
                                              if (_currentImageIndex > 0)
                                              GestureDetector(
                                                onTap: () {
                                                  _pageController.previousPage(
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeInOut,
                                                  );
                                                },
                                                child: Container(
                                                  width: 40,
                                                  margin: const EdgeInsets.only(left: 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.3),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.arrow_back_ios_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                              
                                              // Right arrow
                                              if (_currentImageIndex < event.mediaUrls!.length - 1)
                                              GestureDetector(
                                                onTap: () {
                                                  _pageController.nextPage(
                                                    duration: const Duration(milliseconds: 300),
                                                    curve: Curves.easeInOut,
                                                  );
                                                },
                                                child: Container(
                                                  width: 40,
                                                  margin: const EdgeInsets.only(right: 8),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.3),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.arrow_forward_ios_rounded,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    color: theme.colorScheme.surfaceVariant,
                                    child: Center(
                                      child: Icon(
                                        Icons.event,
                                        size: size.width * 0.15,
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                      ),
                                    ),
                                  ),
                                
                                // Enhanced Page Indicator
                                if (event.mediaUrls != null && event.mediaUrls!.length > 1)
                                  Positioned(
                                    bottom: 20,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        event.mediaUrls!.length,
                                        (index) => AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          width: _currentImageIndex == index ? 24 : 8,
                                          height: 8,
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            color: _currentImageIndex == index
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                // Event Status Badge (if cancelled)
                                if (event.status == EventStatus.cancelled)
                                  Positioned(
                                    top: 20,
                                    right: 20,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.error,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        'CANCELLED',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ),

                              ],
                            ),
                          ),
                        ),
                        // QR Code Container - only visible on larger screens
                        // Add a spacer to push the QR code to the right but not all the way
                        if (isLargeScreen || isMediumScreen)
                          Expanded(child: SizedBox()),
                          
                        // QR code container with slight offset from far right and download text
                        if (isLargeScreen || isMediumScreen)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 40),
                                height: 240,
                                width: 240,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.12),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: GestureDetector(
                                    onTap: () {
                                      // Track QR code interaction
                                      debugPrint('Payment QR Code clicked');
                                      // You can add analytics tracking for payment interactions here
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Image.asset(
                                        'assets/images/vibeqr.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(top: 10, right: 40),
                                child: Text(
                                  'Download the app for a better experience',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

                    // Event Details
                    SliverToBoxAdapter(
                      child: Container(
                        margin: EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: isLargeScreen || isMediumScreen ? size.width * 0.05 : size.width * 0.06,
                            right: size.width * 0.06,
                            top: 24,
                            bottom: 24,
                          ),
                          child: isLargeScreen || isMediumScreen
                            ? _buildLargerScreenLayout(theme, event, size, isLargeScreen, contentMaxWidth)
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              // Event Title with Category Tag
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.title,
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // About the Event Section
                              if (event.description != null && event.description!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                EventAboutSection(description: event.description!),
                              ],
                              
                              // Add more space between About Event and Location sections
                              const SizedBox(height: 32),
                              
                              // Event Details - Using separate cards for each section
                              _buildEventInfoCards(theme, event),
                              
                              // Policies & Terms Section Card
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: theme.colorScheme.outline.withOpacity(0.1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: EventPolicySection(
                                  eventId: event.id,
                                ),
                              ),
                              
                              // Bottom spacing to ensure content is above the navigation bar
                              SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Enhanced Bottom Navigation Bar with Frosted Glass Effect
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: EdgeInsets.only(
                          left: size.width * 0.05,
                          right: size.width * 0.05,
                          top: 16,
                          bottom: padding.bottom + 16,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.85),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                          border: Border(
                            top: BorderSide(
                              color: theme.dividerColor.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Join/Leave Button with Enhanced Design
                            Expanded(
                              flex: 7,
                              child: userParticipationAsync?.when(
                                data: (participation) {
                                  bool isCreator = event.creatorId == currentUser?.id;
                                  bool isParticipant = participation != null;
                                  debugPrint('Is Creator: $isCreator, Is Participant: $isParticipant');

                                  return Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getButtonBoxShadowColor(event, isParticipant, isCreator, theme),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        if (isCreator) {
                                          // For event creators, navigate to event dashboard
                                          context.push('/events/${event.id}/dashboard');
                                        } else if (isParticipant) {
                                          // For paid events where the user is a participant
                                          if (event.ticketPrice != null && event.ticketPrice! > 0) {
                                            // Show a message that ticket is confirmed
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Your ticket is confirmed. Enjoy the event!'),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          } else {
                                            // Only allow leaving for free events
                                            _handleLeaveEvent();
                                          }
                                        } else {
                                          // Check if event is completed before allowing join
                                          final bool isRecurringEvent = event.recurringPattern != null && event.recurringPattern!.isNotEmpty;
                                          final bool eventCompleted = isRecurringEvent
                                              ? RecurringEventUtils.isEventSeriesCompleted(event)
                                              : DateTime.now().isAfter(event.endTime);
                                              
                                          if (eventCompleted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('This event has already ended and cannot be joined.'),
                                                backgroundColor: Colors.orange,
                                              ),
                                            );
                                          } else if (event.ticketPrice != null && event.ticketPrice! > 0) {
                                            // For paid events, navigate to booking screen
                                            context.push(
                                              '/events/${event.id}/booking',
                                              extra: {'event': event},
                                            );
                                          } else {
                                            _handleJoinEvent(event);
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        // Use the primary gradient for paid events that are not completed,
                                        // and when the user is not already a participant
                                        backgroundColor: (!isParticipant && !isCreator && 
                                            // Check if event is still active using proper recurring pattern logic
                                            !(event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                                ? RecurringEventUtils.isEventSeriesCompleted(event)
                                                : DateTime.now().isAfter(event.endTime)) && 
                                            (event.ticketPrice != null && event.ticketPrice! > 0)) 
                                            ? Colors.transparent
                                            : _getButtonColor(event, isParticipant, isCreator, theme),
                                        foregroundColor: theme.colorScheme.onPrimary,
                                        padding: EdgeInsets.zero, // Remove default padding for proper gradient background
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: Ink(
                                        decoration: (!isParticipant && !isCreator && 
                                            // Check if event is still active using proper recurring pattern logic
                                            !(event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                                ? RecurringEventUtils.isEventSeriesCompleted(event)
                                                : DateTime.now().isAfter(event.endTime)) && 
                                            (event.ticketPrice != null && event.ticketPrice! > 0))
                                            ? BoxDecoration(
                                                gradient: AppTheme.primaryGradient,
                                                borderRadius: BorderRadius.circular(16),
                                              )
                                            : null,
                                        child: Container(
                                          height: 56, // Fixed height to prevent overflow
                                          padding: const EdgeInsets.symmetric(horizontal: 20),
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // If it's a paid event and user hasn't joined yet and event hasn't ended
                                              if (!isParticipant && !isCreator && 
                                                  // Check if event is still active using proper recurring pattern logic
                                                  !(event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                                      ? RecurringEventUtils.isEventSeriesCompleted(event)
                                                      : DateTime.now().isAfter(event.endTime)) && 
                                                  (event.ticketPrice != null && event.ticketPrice! > 0)) ...[                                             
                                                // Show booking ticket info with price - using a flat layout instead of nested columns
                                                Expanded(
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      // Book tickets text (left-aligned)
                                                      Text(
                                                        'Book Tickets',
                                                        style: theme.textTheme.titleMedium?.copyWith(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                      
                                                      // Price information (right-aligned)
                                                      Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                                        textBaseline: TextBaseline.alphabetic,
                                                        children: [
                                                          // Vibe price (if available) - larger and more prominent
                                                          if (event.vibePrice != null && event.vibePrice! > 0) ...[                                                     
                                                            Text(
                                                              '₹${event.vibePrice!.toStringAsFixed(0)}',
                                                              style: theme.textTheme.titleMedium?.copyWith(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                          ],
                                                          // Regular price (struck out if vibe price is available)
                                                          Text(
                                                            '₹${event.ticketPrice!.toStringAsFixed(0)}',
                                                            style: theme.textTheme.bodyMedium?.copyWith(
                                                              color: Colors.white.withOpacity(0.7),
                                                              fontWeight: FontWeight.normal,
                                                              fontSize: 13,
                                                              decoration: (event.vibePrice != null && event.vibePrice! > 0) ?
                                                                TextDecoration.lineThrough : null,
                                                              decorationColor: Colors.white.withOpacity(0.7),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ] else ...[
                                                // Standard button for free events or other states
                                                Icon(
                                                  _getButtonIcon(event, isParticipant, isCreator),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _getButtonText(event, isParticipant, isCreator),
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    color: theme.colorScheme.onPrimary,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (_, __) => const SizedBox(),
                              ) ?? const SizedBox(),
                            ),
                            
                            const SizedBox(width: 12),
                            
                            // Chat Button (at fixed width)
                            Container(
                              height: 56,
                              width: 56, 
                              decoration: BoxDecoration(
                                color: userParticipationAsync?.when(
                                  data: (participation) => participation != null 
                                      ? theme.colorScheme.primaryContainer
                                      : theme.colorScheme.primaryContainer.withOpacity(0.5), 
                                  loading: () => theme.colorScheme.primaryContainer.withOpacity(0.5),
                                  error: (_, __) => theme.colorScheme.primaryContainer.withOpacity(0.5),
                                ) ?? theme.colorScheme.primaryContainer.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: userParticipationAsync?.when(
                                  data: (participation) => participation != null ? [
                                    BoxShadow(
                                      color: theme.colorScheme.primary.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ] : null,
                                  loading: () => null,
                                  error: (_, __) => null,
                                ) ?? null,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: userParticipationAsync?.when(
                                    data: (participation) => participation != null ? () {
                                      HapticFeedback.mediumImpact();
                                      context.push('/events/${widget.eventId}/chat');
                                    } : null,
                                    loading: () => null,
                                    error: (_, __) => null,
                                  ) ?? null,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Center(
                                    child: Icon(
                                      Icons.chat_bubble_outline,
                                      color: userParticipationAsync?.when(
                                        data: (participation) => participation != null 
                                            ? theme.colorScheme.onPrimaryContainer
                                            : theme.colorScheme.onPrimaryContainer.withOpacity(0.5), 
                                        loading: () => theme.colorScheme.onPrimaryContainer.withOpacity(0.5),
                                        error: (_, __) => theme.colorScheme.onPrimaryContainer.withOpacity(0.5),
                                      ) ?? theme.colorScheme.onPrimaryContainer.withOpacity(0.5),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Show instructional overlay for first-time users
                if (_showInstructions)
                  EventDetailsInstructionsOverlay(
                    onDismiss: _dismissInstructions,
                    screenSize: MediaQuery.of(context).size,
                  ),
              ],
            );
          },
          loading: () => const LoadingWidget(),
          error: (error, _) => Center(
            child: Text('Error: $error'),
          ),
        ),
      ),
    );
  }

  // Helper method to build a responsive layout for larger screens (tablet/desktop)
  Widget _buildLargerScreenLayout(ThemeData theme, Event event, Size size, bool isLargeScreen, double contentMaxWidth) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100), // Add bottom padding to ensure content isn't hidden
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth),
          child: Column(  
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Event Title with Category Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Main two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column - About section and participants
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // About section
                    if (event.description != null && event.description!.isNotEmpty) ...[  
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Directly include the EventAboutSection which already has its own header
                            EventAboutSection(description: event.description!),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Participants section
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        child: FutureBuilder<List<EventParticipant>>(
                          future: ref.read(eventParticipantControllerProvider.notifier).loadParticipants(event.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            
                            final participants = snapshot.data ?? [];
                            
                            return EventParticipantsSection(
                              participants: participants,
                              onSeeAll: () => context.push('/events/${event.id}/participants'),
                              // Show more participants on larger screens
                              maxDisplayed: 5,
                            );
                          },
                        ),
                      ),
                    ),
                    
                    // Policies section
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        child: EventPolicySection(
                          eventId: event.id,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 24),
              
              // Right column - Info cards (location, date, etc)
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location Section Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        child: EventLocationSection(
                          location: event.location ?? 'No location specified',
                          onTap: event.location != null ? () {
                            // Handle opening location in maps
                            final url = Uri.encodeFull('https://maps.google.com/?q=${event.location}');
                            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                          } : null,
                        ),
                      ),
                    ),
                    
                    // Visibility Section Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        child: EventVisibilitySection(
                          visibility: event.visibility,
                        ),
                      ),
                    ),
                    
                    // Date & Time Section Card
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        child: EventDateTimeSection(
                          startTime: event.startTime,
                          endTime: event.endTime,
                          onAddToCalendar: () => _addToCalendar(event),
                          recurringPattern: event.recurringPattern,
                        ),
                      ),
                    ),
                    
                    // Ticket information intentionally removed for larger screens
                    // to maintain a clean, minimalist UI as requested
                  ],
                ),
              ),
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to build all event info cards for mobile layout
  Widget _buildEventInfoCards(ThemeData theme, Event event) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Location Section Card
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: EventLocationSection(
              location: event.location ?? 'No location specified',
              onTap: event.location != null ? () {
                // Handle opening location in maps
                final url = Uri.encodeFull('https://maps.google.com/?q=${event.location}');
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              } : null,
            ),
          ),
        ),
        
        // Visibility Section Card
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: EventVisibilitySection(
              visibility: event.visibility,
            ),
          ),
        ),
        
        // Date & Time Section Card
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: EventDateTimeSection(
              startTime: event.startTime,
              endTime: event.endTime,
              onAddToCalendar: () => _addToCalendar(event),
              recurringPattern: event.recurringPattern,
            ),
          ),
        ),
        
        // Participants Section Card
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            child: FutureBuilder<List<EventParticipant>>(
              future: ref.read(eventParticipantControllerProvider.notifier).loadParticipants(event.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                final participants = snapshot.data ?? [];
                
                return EventParticipantsSection(
                  participants: participants,
                  onSeeAll: () => context.push('/events/${event.id}/participants'),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailSection(
    ThemeData theme,
    String title,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsSection(String eventId) {
    final currentUser = ref.watch(currentUserProvider);
    final event = ref.watch(eventDetailsProvider(eventId)).value;
    final isCreator = currentUser != null && event?.creatorId == currentUser.id;
    final theme = Theme.of(context);

    return Consumer(
      builder: (context, ref, child) {
        final participantsAsync = ref.watch(eventParticipantControllerProvider);
        
        return participantsAsync.when(
          data: (participants) {
            if (participants.isEmpty) {
              return Text('No participants yet', 
                  style: theme.textTheme.bodyMedium);
            }
            
            // Use a simple ListView with no vertical expansion
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: participants.length.clamp(0, 10),
              itemBuilder: (context, index) {
                final participant = participants[index];
                
                // For the last visible item, show "more" indicator if needed
                if (index == 9 && participants.length > 10) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                      child: Center(
                        child: Text(
                          '+${participants.length - 9}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }
                
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Avatar(
                    url: participant.avatarUrl,
                    size: 48,
                    name: participant.fullName ?? participant.username,
                    userId: participant.userId,
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: SizedBox(
            width: 20, height: 20, 
            child: CircularProgressIndicator(strokeWidth: 2)
          )),
          error: (_, __) => Text(
            'Error loading participants', 
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)
          ),
        );
      },
    );
  }

  Future<void> _handleJoinEvent(Event event) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      context.go('/login');
      return;
    }

    try {
      // Check if user has already completed requirements
      final responseRepo = ref.read(eventResponseRepositoryProvider);
      final hasCompleted = await responseRepo.hasCompletedRequirements(
        event.id,
        currentUser.id,
      );

      if (!hasCompleted) {
        // Show full-screen requirements view
        final completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => EventJoinRequirementsDialog(event: event),
          ),
        ) ?? false;

        if (!completed) {
          return; // User cancelled
        }
      }

      // Now join the event
      await ref.read(eventParticipantControllerProvider.notifier).joinEvent(
        event.id,
        currentUser.id,
      );

      // Invalidate relevant providers to refresh UI
      ref.invalidate(userParticipationProvider((
        eventId: event.id,
        userId: currentUser.id,
      )));
      ref.invalidate(eventParticipantControllerProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the event!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLeaveEvent() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final event = await ref.read(eventDetailsProvider(widget.eventId).future);
    if (event == null) return;

    debugPrint('Attempting to leave event: ${event.id} by user: ${currentUser.id}');

    try {
      await ref
          .read(eventParticipantControllerProvider.notifier)
          .leaveEvent(event.id, currentUser.id);
      
      debugPrint('Successfully left event: ${event.id}');
      
      // Invalidate both providers to ensure fresh data
      ref.invalidate(userParticipationProvider((
        eventId: event.id,
        userId: currentUser.id,
      )));
      ref.invalidate(eventParticipantControllerProvider);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully left event')),
      );
    } catch (e) {
      debugPrint('Failed to leave event: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to leave event')),
      );
    }
  }

  String _formatEventDate(DateTime start, DateTime end) {
    final startDate = DateFormat('MMM d, y').format(start);
    final startTime = DateFormat('h:mm a').format(start);
    final endTime = DateFormat('h:mm a').format(end);
    return '$startDate • $startTime - $endTime';
  }

  Future<void> _handleEventAction(String action, Event event) async {
    switch (action) {
      case 'cancel':
        _showEventActionDialog(
          EventActionType.cancelled,
          (reason) => _cancelEvent(event, reason),
        );
        break;
      case 'delete':
        _showEventActionDialog(
          EventActionType.deleted,
          (reason) => _deleteEvent(event, reason),
        );
        break;
    }
  }

  void _showEventActionDialog(EventActionType actionType, Function(String) onConfirm) {
    showDialog(
      context: context,
      builder: (context) => EventActionDialog(
        actionType: actionType,
        onConfirm: onConfirm,
      ),
    );
  }

  Future<void> _cancelEvent(Event event, String reason) async {
    try {
      await ref.read(eventControllerProvider.notifier).cancelEvent(
        event.id,
        reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event cancelled successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel event: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteEvent(Event event, String reason) async {
    try {
      await ref.read(eventControllerProvider.notifier).deleteEvent(
        event.id,
        reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete event: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareEvent(Event event) async {
    try {
      // Generate shareable link using AppRoutes helper
      final String shareableLink = AppRoutes.getEventDetailsUri(event.id);
      
      // Build sharing text with shareable link
      final String eventDetails = '''
${event.title}

📅 ${DateFormat('MMM dd, yyyy').format(event.startTime)} at ${DateFormat('hh:mm a').format(event.startTime)}
📍 ${event.location ?? 'Location not specified'}

${event.description ?? ''}

🔗 ${shareableLink}
''';

      // Use Share.share for cross-platform sharing
      await Share.share(
        eventDetails,
        subject: 'Check out this event: ${event.title}',
      );
    } catch (e) {
      debugPrint('Error sharing event: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share event: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addToCalendar(Event event) async {
    try {
      debugPrint('Adding to calendar: ${event.title}');
      
      // Check platform
      if (!mounted) return;
      
      if (kIsWeb) {
        debugPrint('Platform: Web');
        await _launchGoogleCalendar(event);
        return;
      }

      debugPrint('Platform: ${Platform.operatingSystem}');
      
      // For mobile platforms (Android & iOS)
      final hasPermission = await _requestCalendarPermissions();
      debugPrint('Calendar permission status: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('Calendar permission denied');
        return;
      }

      if (Platform.isAndroid) {
        debugPrint('Trying Android calendar...');
        
        // First try the native calendar intent
        final startMillis = event.startTime.millisecondsSinceEpoch;
        final endMillis = event.endTime.millisecondsSinceEpoch;
        
        final nativeUri = Uri.parse(
          'content://com.android.calendar/time/${startMillis}?'
          'end=${endMillis}&'
          'title=${Uri.encodeComponent(event.title)}&'
          'description=${Uri.encodeComponent(event.description ?? "")}&'
          'location=${Uri.encodeComponent(event.location ?? "")}'
        );
        
        debugPrint('Trying native calendar URI: $nativeUri');
        
        try {
          if (await canLaunchUrl(nativeUri)) {
            await launchUrl(
              nativeUri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
            _showSuccessMessage('Opening calendar...');
            return;
          }
        } catch (e) {
          debugPrint('Native calendar failed: $e');
        }
        
        // Try alternate intent
        final alternateUri = Uri.parse(
          'content://calendar/time/${startMillis}?'
          'end=${endMillis}&'
          'title=${Uri.encodeComponent(event.title)}&'
          'description=${Uri.encodeComponent(event.description ?? "")}&'
          'location=${Uri.encodeComponent(event.location ?? "")}'
        );
        
        debugPrint('Trying alternate calendar URI: $alternateUri');
        
        try {
          if (await canLaunchUrl(alternateUri)) {
            await launchUrl(
              alternateUri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
            _showSuccessMessage('Opening calendar...');
            return;
          }
        } catch (e) {
          debugPrint('Alternate calendar failed: $e');
        }

        // If both native intents fail, try a more generic intent
        final genericUri = Uri.parse(
          'content://com.android.calendar/events/edit?'
          'title=${Uri.encodeComponent(event.title)}&'
          'description=${Uri.encodeComponent(event.description ?? "")}&'
          'eventLocation=${Uri.encodeComponent(event.location ?? "")}&'
          'beginTime=$startMillis&'
          'endTime=$endMillis'
        );
        
        debugPrint('Trying generic calendar URI: $genericUri');
        
        try {
          if (await canLaunchUrl(genericUri)) {
            await launchUrl(
              genericUri,
              mode: LaunchMode.externalNonBrowserApplication,
            );
            _showSuccessMessage('Opening calendar...');
            return;
          }
        } catch (e) {
          debugPrint('Generic calendar failed: $e');
        }

        // As a last resort, try Google Calendar
        debugPrint('All native calendar attempts failed, trying Google Calendar...');
        final googleParams = Uri.encodeFull(
          'text=${event.title}'
          '&details=${event.description ?? ""}'
          '&location=${event.location ?? ""}'
          '&dates=${event.startTime.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0]}Z'
          '/${event.endTime.toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.')[0]}Z'
        );
        
        final googleUri = Uri.parse('https://calendar.google.com/calendar/render?action=TEMPLATE&$googleParams');
        debugPrint('Trying Google Calendar URI: $googleUri');
        
        try {
          if (await canLaunchUrl(googleUri)) {
            await launchUrl(
              googleUri,
              mode: LaunchMode.externalApplication,
            );
            _showSuccessMessage('Opening Google Calendar...');
            return;
          }
        } catch (e) {
          debugPrint('Google Calendar failed: $e');
        }

        // If all attempts fail, show error message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find a calendar app. Please install a calendar app and try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (Platform.isIOS) {
        debugPrint('Trying iOS calendar...');
        final uri = Uri.parse('calshow://');
        if (await canLaunchUrl(uri)) {
          debugPrint('Launching iOS Calendar...');
          await launchUrl(uri);
          _showSuccessMessage('Opening calendar...');
        } else {
          debugPrint('Could not launch iOS Calendar');
          throw Exception('Could not launch calendar');
        }
      }
    } catch (e) {
      debugPrint('Error adding to calendar: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add event to calendar: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _requestCalendarPermissions() async {
    try {
      // First check the current permission status
      final status = await Permission.calendar.status;
      debugPrint('Initial calendar permission status: $status');
      
      if (status.isGranted) {
        debugPrint('Calendar permission already granted');
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        debugPrint('Calendar permission permanently denied');
        if (!mounted) return false;
        
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Calendar Permission Required'),
            content: const Text('Calendar permission is required to add events. Please enable it in settings.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ) ?? false;
        
        debugPrint('Should open settings: $shouldOpenSettings');
        if (shouldOpenSettings) {
          await openAppSettings();
          // Recheck permission after returning from settings
          final newStatus = await Permission.calendar.status;
          debugPrint('New permission status after settings: $newStatus');
          return newStatus.isGranted;
        }
        return false;
      }
      
      // Request permission with system dialog
      debugPrint('Requesting calendar permission...');
      final result = await Permission.calendar.request();
      debugPrint('Calendar permission request result: $result');
      return result.isGranted;
    } catch (e) {
      debugPrint('Error requesting calendar permission: $e');
      return false;
    }
  }

  Future<void> _launchGoogleCalendar(Event event) async {
    final startTime = event.startTime.toUtc();
    final endTime = event.endTime.toUtc();
    
    // Format dates for Google Calendar URL (YYYYMMDDTHHmmssZ)
    final formattedStart = startTime.toIso8601String().replaceAll(RegExp(r'[-:]|\.\d+'), '');
    final formattedEnd = endTime.toIso8601String().replaceAll(RegExp(r'[-:]|\.\d+'), '');
    
    final intent = Uri.parse(
      'https://calendar.google.com/calendar/render'
      '?action=TEMPLATE'
      '&text=${Uri.encodeComponent(event.title)}'
      '&dates=$formattedStart/$formattedEnd'
      '&details=${Uri.encodeComponent(event.description ?? '')}'
      '&location=${Uri.encodeComponent(event.location ?? '')}'
    );

    if (await canLaunchUrl(intent)) {
      await launchUrl(
        intent,
        mode: LaunchMode.externalApplication,
      );
      _showSuccessMessage('Opening Google Calendar...');
    } else {
      throw Exception('Could not launch Google Calendar');
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color _getButtonBoxShadowColor(Event event, bool isParticipant, bool isCreator, ThemeData theme) {
    // Check if this is a recurring event and if it has future occurrences
    final bool isRecurringEvent = event.recurringPattern != null && event.recurringPattern!.isNotEmpty;
    final bool eventCompleted = isRecurringEvent
        ? RecurringEventUtils.isEventSeriesCompleted(event)
        : DateTime.now().isAfter(event.endTime);
    
    if (eventCompleted) {
      return Colors.grey.withOpacity(0.3);
    } else if (isParticipant && !isCreator && (event.ticketPrice == null || event.ticketPrice == 0)) {
      // Only show red for free events where regular participant wants to leave
      return theme.colorScheme.error.withOpacity(0.3);
    } else if (isCreator || (isParticipant && event.ticketPrice != null && event.ticketPrice! > 0)) {
      // For creators and paid event participants, use primary color
      return theme.colorScheme.primary.withOpacity(0.3);
    } else {
      return theme.colorScheme.primary.withOpacity(0.3);
    }
  }

  Color _getButtonColor(Event event, bool isParticipant, bool isCreator, ThemeData theme) {
    // Check if this is a recurring event and if it has future occurrences
    final bool isRecurringEvent = event.recurringPattern != null && event.recurringPattern!.isNotEmpty;
    final bool eventCompleted = isRecurringEvent
        ? RecurringEventUtils.isEventSeriesCompleted(event)
        : DateTime.now().isAfter(event.endTime);
    
    if (eventCompleted) {
      return Colors.grey;
    } else if (isParticipant && !isCreator && (event.ticketPrice == null || event.ticketPrice == 0)) {
      // Only show red for free events where regular participant wants to leave
      return theme.colorScheme.error;
    } else if (isCreator || (isParticipant && event.ticketPrice != null && event.ticketPrice! > 0)) {
      // For creators and paid event participants, use primary color
      return theme.colorScheme.primary;
    } else {
      return theme.colorScheme.primary;
    }
  }

  IconData _getButtonIcon(Event event, bool isParticipant, bool isCreator) {
    // Check if this is a recurring event and if it has future occurrences
    final bool isRecurringEvent = event.recurringPattern != null && event.recurringPattern!.isNotEmpty;
    final bool eventCompleted = isRecurringEvent
        ? RecurringEventUtils.isEventSeriesCompleted(event)
        : DateTime.now().isAfter(event.endTime);
    
    if (eventCompleted) {
      return Icons.event_busy;
    } else if (isCreator) {
      // For event creators
      return Icons.dashboard_outlined;
    } else if (isParticipant) {
      // For paid events where user is a participant, show a ticket icon
      if (event.ticketPrice != null && event.ticketPrice! > 0) {
        return Icons.confirmation_num_outlined;
      }
      // For free events where user is a participant
      return Icons.exit_to_app;
    } else {
      return Icons.group_add;
    }
  }

  String _getButtonText(Event event, bool isParticipant, bool isCreator) {
    // Check if this is a recurring event and if it has future occurrences
    final bool isRecurringEvent = event.recurringPattern != null && event.recurringPattern!.isNotEmpty;
    final bool eventCompleted = isRecurringEvent
        ? RecurringEventUtils.isEventSeriesCompleted(event)
        : DateTime.now().isAfter(event.endTime);
    
    if (eventCompleted) {
      return 'Event Completed';
    } else if (isCreator) {
      // For event creators
      return 'Event Dashboard';
    } else if (isParticipant) {
      // For paid events where user is a participant, show a different message
      if (event.ticketPrice != null && event.ticketPrice! > 0) {
        return 'Ticket Confirmed';
      }
      // For free events where user is a participant
      return 'Leave Event';
    } else {
      // For paid events, we'll handle the text display separately in the button UI
      if (event.ticketPrice != null && event.ticketPrice! > 0) {
        return 'Book Tickets';
      } else {
        return 'Join Event';
      }
    }
  }

  Color _getVisibilityColor(EventVisibility visibility, ThemeData theme) {
    switch (visibility) {
      case EventVisibility.public:
        return Colors.green;
      case EventVisibility.private:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
