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
import '../widgets/access_code_bottom_sheet.dart';
import '../widgets/event_action_dialog.dart';
import 'package:scompass_07/core/widgets/edge_to_edge_container.dart';

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

  @override
  void initState() {
    super.initState();
    _loadEventDetails();
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
    
    // Load event details
    ref.read(eventDetailsProvider(eventId));
    
    // Load participants
    await ref.read(eventParticipantControllerProvider.notifier).loadParticipants(eventId);
    
    // Check participation status
    final participationStatus = await ref.read(userParticipationProvider((
      eventId: eventId,
      userId: currentUser.id,
    )));
    
    debugPrint('Initial participation status for user ${currentUser.id}: $participationStatus');
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
    final appBarColor = isDark ? Colors.black : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;
    
    // Calculate responsive dimensions
    final imageHeight = size.height * 0.45;
    final imageWidth = size.width * 0.85;
    
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
                    // Custom App Bar with Back Button
                    SliverAppBar(
                      backgroundColor: appBarColor,
                      foregroundColor: foregroundColor,
                      elevation: 0,
                      leading: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: foregroundColor,
                          size: 20,
                        ),
                        onPressed: () => context.pop(),
                      ),
                      actions: [
                        if (isCreator)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: foregroundColor,
                            ),
                            onSelected: (value) => _handleEventAction(value, event),
                            color: appBarColor,
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'cancel',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.cancel,
                                      color: foregroundColor,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Cancel Event',
                                      style: TextStyle(color: foregroundColor),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_forever,
                                      color: theme.colorScheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete Event',
                                      style: TextStyle(color: theme.colorScheme.error),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.share_outlined,
                            color: theme.colorScheme.onSurface,
                          ),
                          onPressed: () => _shareEvent(event),
                        ),
                      ],
                    ),
                    
                    // Image Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: size.width * 0.075,
                          vertical: 16,
                        ),
                        child: SizedBox(
                          height: imageHeight,
                          width: imageWidth,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              children: [
                                // Image Carousel
                                if (event.mediaUrls != null && event.mediaUrls!.isNotEmpty)
                                  PageView.builder(
                                    controller: _pageController,
                                    onPageChanged: (index) {
                                      setState(() {
                                        _currentImageIndex = index;
                                      });
                                    },
                                    itemCount: event.mediaUrls!.length,
                                    itemBuilder: (context, index) {
                                      return Image.network(
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
                                      );
                                    },
                                  )
                                else
                                  Center(
                                    child: Icon(
                                      Icons.event,
                                      size: size.width * 0.15,
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                
                                // Page Indicator
                                if (event.mediaUrls != null && event.mediaUrls!.length > 1)
                                  Positioned(
                                    bottom: 16,
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
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface.withOpacity(0.4),
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

                    // Event Details
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(size.width * 0.05),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Event Type and Price Tag
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: event.eventType == EventType.free
                                            ? Colors.green.withOpacity(0.1)
                                            : theme.colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: event.eventType == EventType.free
                                              ? Colors.green
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                      child: Text(
                                        event.eventType == EventType.free
                                            ? 'FREE'
                                            : event.eventType == EventType.paid && event.ticketPrice != null
                                                ? '${event.currency ?? 'USD'} ${event.ticketPrice!.toStringAsFixed(2)}'
                                                : 'INVITATION ONLY',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: event.eventType == EventType.free
                                              ? Colors.green
                                              : theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.primaryGradientStart,
                                        AppTheme.primaryGradientEnd,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: () => _addToCalendar(event),
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                    ).copyWith(
                                      backgroundColor: MaterialStateProperty.all(Colors.transparent),
                                      overlayColor: MaterialStateProperty.resolveWith<Color?>(
                                        (states) {
                                          if (states.contains(MaterialState.pressed)) {
                                            return Colors.white.withOpacity(0.1);
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      'Add to Calendar',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (event.category != null)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.category_outlined,
                                      size: 16,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      event.category!,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (event.status == EventStatus.cancelled)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: theme.colorScheme.error),
                                ),
                                child: Text(
                                  'CANCELLED',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            SizedBox(height: size.height * 0.02),
                            _buildDetailSection(
                              theme,
                              'Date & Time',
                              _formatEventDate(event.startTime, event.endTime),
                              Icons.calendar_today,
                            ),
                            SizedBox(height: size.height * 0.015),
                            _buildDetailSection(
                              theme,
                              'Location',
                              event.location ?? 'No location specified',
                              Icons.location_on,
                            ),
                            SizedBox(height: size.height * 0.015),
                            _buildDetailSection(
                              theme,
                              'Visibility',
                              event.visibility.name.toUpperCase(),
                              event.visibility == EventVisibility.public
                                  ? Icons.public
                                  : event.visibility == EventVisibility.private
                                      ? Icons.lock
                                      : Icons.link_off,
                              color: event.visibility == EventVisibility.public
                                  ? Colors.green
                                  : event.visibility == EventVisibility.private
                                      ? Colors.red
                                      : Colors.grey,
                            ),
                            SizedBox(height: size.height * 0.03),
                            if (event.description != null && event.description!.isNotEmpty) ...[
                              Text(
                                'About',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: size.height * 0.01),
                              Text(
                                event.description!,
                                style: theme.textTheme.bodyLarge,
                              ),
                              SizedBox(height: size.height * 0.03),
                            ],
                            _buildParticipantsSection(event.id),
                            // Add bottom padding for content to be visible above bottom bar
                            SizedBox(height: size.height * 0.12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Bottom Navigation Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ClipRRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: EdgeInsets.only(
                          left: size.width * 0.05,
                          right: size.width * 0.05,
                          top: 12,
                          bottom: padding.bottom + 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withOpacity(0.8),
                          border: Border(
                            top: BorderSide(
                              color: theme.dividerColor.withOpacity(0.1),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Join/Leave Button
                            Expanded(
                              flex: 7,
                              child: userParticipationAsync?.when(
                                data: (participation) {
                                  bool isCreator = event.creatorId == currentUser?.id; // Check if the user is the creator
                                  bool isParticipant = participation != null; // Check if the user is a participant
                                  debugPrint('Is Creator: $isCreator, Is Participant: $isParticipant'); // Debug print

                                  return ElevatedButton(
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      if (isParticipant || isCreator) {
                                        _handleLeaveEvent(); // Leave if participant or creator
                                      } else {
                                        _handleJoinEvent(); // Join if not a participant
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: (isParticipant || isCreator)
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.primary,
                                      foregroundColor: theme.colorScheme.onPrimary,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          (isParticipant || isCreator) ? Icons.exit_to_app : Icons.group_add,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          (isParticipant || isCreator) ? 'Leave Event' : 'Join Event',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: theme.colorScheme.onPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (_, __) => const SizedBox(),
                              ) ?? const SizedBox(),
                            ),
                            SizedBox(width: size.width * 0.03),
                            // Chat Button
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.mediumImpact();
                                      context.push('/events/${widget.eventId}/chat');
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            color: theme.colorScheme.onPrimaryContainer,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Chat',
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              color: theme.colorScheme.onPrimaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
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
    return Consumer(
      builder: (context, ref, child) {
        final participantsAsync = ref.watch(eventParticipantControllerProvider);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/events/$eventId/participants'),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            participantsAsync.when(
              data: (participants) {
                if (participants.isEmpty) {
                  return const Text('No participants yet');
                }
                return SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: participants.length.clamp(0, 5),
                    itemBuilder: (context, index) {
                      final participant = participants[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          backgroundImage: participant.avatarUrl != null
                              ? NetworkImage(participant.avatarUrl!)
                              : null,
                          child: participant.avatarUrl == null
                              ? Text(
                                  participant.fullName?[0].toUpperCase() ??
                                      participant.username?[0].toUpperCase() ??
                                      '?',
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading participants'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleJoinEvent() async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final event = await ref.read(eventDetailsProvider(widget.eventId).future);
    if (event == null) return;

    debugPrint('Attempting to join event: ${event.id} by user: ${currentUser.id}');
    debugPrint('Event visibility: ${event.visibility}');

    try {
      // Check if event is private
      if (event.visibility == EventVisibility.private) {
        debugPrint('Event is private, showing access code bottom sheet');
        // Show access code bottom sheet
        final success = await AccessCodeBottomSheet.show(
          context,
          eventId: event.id,
          eventTitle: event.title,
        );

        // If access code was not provided or invalid, return
        if (success != true) {
          debugPrint('Access code verification failed or cancelled');
          return;
        }
        debugPrint('Access code verified successfully');
      } else {
        // For public events, directly join
        debugPrint('Event is public, joining directly');
        await ref
            .read(eventParticipantControllerProvider.notifier)
            .joinEvent(event.id, currentUser.id);
      }
      
      debugPrint('Successfully joined event: ${event.id}');
      
      // Invalidate both providers to ensure fresh data
      ref.invalidate(userParticipationProvider((
        eventId: event.id,
        userId: currentUser.id,
      )));
      ref.invalidate(eventParticipantControllerProvider);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully joined event')),
      );
    } catch (e) {
      debugPrint('Failed to join event: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to join event')),
      );
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
          SnackBar(content: Text('Failed to cancel event: ${e.toString()}')),
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
          SnackBar(content: Text('Failed to delete event: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _shareEvent(Event event) async {
    final String eventDetails = '''
${event.title}

📅 ${DateFormat('MMM dd, yyyy').format(event.startTime)} at ${DateFormat('hh:mm a').format(event.startTime)}
📍 ${event.location ?? 'Location not specified'}

${event.description ?? ''}
''';
    
    await Share.share(eventDetails, subject: 'Check out this event: ${event.title}');
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
      await launchUrl(intent, mode: LaunchMode.externalApplication);
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
}
