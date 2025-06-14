import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/config/routes.dart';
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/features/events/controllers/event_controller.dart';
import 'package:scompass_07/features/events/models/event_model.dart';
import 'package:scompass_07/shared/widgets/responsive_scaffold.dart';
import 'package:scompass_07/shared/widgets/bottom_nav_bar.dart';
import 'package:scompass_07/shared/widgets/error_widget.dart';
import 'package:scompass_07/shared/widgets/loading_widget.dart';
import 'package:scompass_07/shared/icons/nav_icons.dart';
import 'package:scompass_07/shared/widgets/notification_badge.dart';
import 'package:scompass_07/features/notifications/providers/notifications_provider.dart';
import '../../../config/theme.dart';
import '../../payments/providers/payment_provider.dart';
import '../models/event_participant_model.dart';
import '../widgets/event_filters.dart';
import '../widgets/event_search_bar.dart';
import '../widgets/event_card_stack.dart';
import '../widgets/swipe_instructions_overlay.dart';
import '../widgets/banner_widget.dart';
// import '../widgets/event_card_ad.dart'; // Ad functionality temporarily disabled
import 'dart:async';
import 'package:scompass_07/core/widgets/edge_to_edge_container.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../widgets/event_list_item.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  EventStatus? _selectedStatus;
  String? _selectedCategory;
  EventSortOption _selectedSort = EventSortOption.dateDesc;
  Timer? _searchDebounce;
  List<String> _categories = [];
  bool _isModalOpen = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _logoFadeAnimation;
  Size? _screenSize;
  bool _showInstructions = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));
    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Use AutoDisposeFutureProvider to handle state cleanup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.forward();
        // Only refresh if data is not already available
        final currentEvents = ref.read(eventControllerProvider).value;
        if (currentEvents == null || currentEvents.isEmpty) {
          ref.refresh(eventControllerProvider);
        }
        
        // Check if user has seen swipe instructions
        _checkShowInstructions();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cache screen size to prevent layout rebuilds
    _screenSize = MediaQuery.of(context).size;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showFilters() {
    if (_isModalOpen) return; // Prevent multiple modals
    setState(() => _isModalOpen = true);
    
    // Get unique categories from events
    final events = ref.read(eventControllerProvider).value ?? [];
    final uniqueCategories = events
        .where((e) => e.category != null)
        .map((e) => e.category!)
        .toSet()
        .toList()
      ..sort();
    
    setState(() {
      _categories = uniqueCategories;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      elevation: 2,
      constraints: BoxConstraints(
        maxHeight: _screenSize!.height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => WillPopScope(
        onWillPop: () async {
          setState(() => _isModalOpen = false);
          return true;
        },
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          snap: true,
          snapSizes: const [0.3, 0.6, 0.9],
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: EventFilters(
              selectedStatus: _selectedStatus,
              selectedCategory: _selectedCategory,
              selectedSort: _selectedSort,
              categories: _categories,
              onStatusChanged: (status) {
                setState(() {
                  _selectedStatus = status;
                  _isModalOpen = false;
                });
                Navigator.pop(context);
              },
              onCategoryChanged: (category) {
                setState(() {
                  _selectedCategory = category;
                  _isModalOpen = false;
                });
                Navigator.pop(context);
              },
              onSortChanged: (sort) {
                setState(() {
                  _selectedSort = sort;
                  _isModalOpen = false;
                });
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    ).whenComplete(() => setState(() => _isModalOpen = false));
  }

  void _onSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _searchQuery = query);
      }
    });
  }

  List<Event> _filterAndSortEvents(List<Event> events) {
    return events.where((event) {
      final matchesSearch = _searchQuery.isEmpty ||
          event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (event.description?.toLowerCase() ?? '').contains(_searchQuery.toLowerCase()) ||
          (event.location?.toLowerCase() ?? '').contains(_searchQuery.toLowerCase()) ||
          (event.category?.toLowerCase() ?? '').contains(_searchQuery.toLowerCase());

      final matchesStatus = _selectedStatus == null || event.currentStatus == _selectedStatus;
      final matchesCategory = _selectedCategory == null || 
          (event.category?.toLowerCase() == _selectedCategory?.toLowerCase() && event.category != null);

      // No longer filtering based on payment status
      return matchesSearch && matchesStatus && matchesCategory;
    }).toList()
      ..sort((a, b) {
        switch (_selectedSort) {
          case EventSortOption.dateAsc:
            return a.startTime.compareTo(b.startTime);
          case EventSortOption.dateDesc:
            return b.startTime.compareTo(a.startTime);
          case EventSortOption.titleAsc:
            return a.title.compareTo(b.title);
          case EventSortOption.titleDesc:
            return b.title.compareTo(a.title);
        }
      });
  }

  Future<void> _checkShowInstructions() async {
    final hasSeenInstructions = await hasSeenSwipeInstructions();
    if (!hasSeenInstructions && mounted) {
      setState(() {
        _showInstructions = true;
      });
    }
  }

  void _dismissInstructions() {
    setState(() {
      _showInstructions = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? AppTheme.darkBackgroundColor : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;

    return EdgeToEdgeContainer(
      statusBarColor: Colors.transparent,
      navigationBarColor: theme.colorScheme.background,
      child: ResponsiveScaffold(
        body: Stack(
          children: [
            // Gradient Banner with SafeArea
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppTheme.primaryGradientStart,
                        AppTheme.primaryGradientEnd,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "India's #1st Swipe-to-Join Travel Experience App",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Main Content with proper padding
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.refresh(eventControllerProvider);
            },
            child: eventsAsync.when(
              data: (events) {
                final filteredEvents = _filterAndSortEvents(events);
                if (filteredEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No events found',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters or search',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), // Added bottom padding for better scroll experience
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Determine if we're on a large screen (desktop/tablet landscape)
                      final isLargeScreen = constraints.maxWidth > 900;
                      
                      // Calculate maximum card width
                      final maxCardWidth = isLargeScreen 
                          ? 550.0  // Fixed width for larger screens
                          : constraints.maxWidth;
                      
                      // If we're on a small screen, just show the card
                      if (!isLargeScreen) {
                                return Column(
                                  children: [
                                    // Enhanced Search Bar with matching width
                                    SizedBox(
                                      width: maxCardWidth,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                                        child: Container(
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: theme.colorScheme.outline.withOpacity(0.12),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.shadowColor.withOpacity(0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: TextField(
                                                onChanged: (value) {
                                                  setState(() {
                                                    _searchQuery = value.trim();
                                                  });
                                                },
                                                style: theme.textTheme.bodyLarge?.copyWith(
                                                  color: theme.colorScheme.onSurface,
                                                  letterSpacing: 0.2,
                                                ),
                                                cursorColor: theme.colorScheme.primary,
                                                cursorWidth: 1.5,
                                                decoration: InputDecoration(
                                                  hintText: 'Search for events...',
                                                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                                    letterSpacing: 0.2,
                                                  ),
                                                  prefixIcon: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                                    child: Icon(
                                                      Icons.search_rounded,
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  prefixIconConstraints: const BoxConstraints(
                                                    minWidth: 56,
                                                    minHeight: 52,
                                                  ),
                                                  suffixIcon: _searchQuery.isNotEmpty
                                                      ? GestureDetector(
                                                          onTap: () {
                                                            setState(() {
                                                              _searchQuery = '';
                                                            });
                                                          },
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                                            child: Icon(
                                                              Icons.close_rounded,
                                                              color: theme.colorScheme.onSurfaceVariant,
                                                              size: 20,
                                                            ),
                                                          ),
                                                        )
                                                      : null,
                                                  suffixIconConstraints: const BoxConstraints(
                                                    minWidth: 52,
                                                    minHeight: 52,
                                                  ),
                                                  border: InputBorder.none,
                                                  enabledBorder: InputBorder.none,
                                                  focusedBorder: InputBorder.none,
                                                  filled: true,
                                                  fillColor: theme.colorScheme.surface,
                                                  contentPadding: const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    SizedBox(
                                      width: maxCardWidth,
                                      height: MediaQuery.of(context).size.height * 0.68,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Stack(
                              children: [
                                EventCardStack(
                                  events: filteredEvents,
                                  onSwipe: (event, isRight) {
                                    if (isRight) {
                                      // Capture scaffold messenger before async operation
                                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                                      final eventTitle = event.title;
                                      // Add to favorites
                                      ref.read(favoriteEventsProvider.notifier).favoriteEvent(event.id).then((_) {
                                        // Show success snackbar if still mounted
                                        if (mounted) {
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Added $eventTitle to favorites'),
                                              action: SnackBarAction(
                                                label: 'UNDO',
                                                onPressed: () {
                                                  ref.read(favoriteEventsProvider.notifier).unfavoriteEvent(event.id);
                                                },
                                              ),
                                              duration: const Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      }).catchError((e) {
                                        // Show error snackbar if still mounted
                                        if (mounted) {
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text('Failed to favorite event: ${e.toString()}'),
                                              backgroundColor: theme.colorScheme.error,
                                            ),
                                          );
                                        }
                                      });
                                    }
                                  },
                                  onTap: (event) => context.goNamed('event-details', pathParameters: {'eventId': event.id}),
                                  onStackEmpty: () => ref.refresh(eventControllerProvider),
                                ),
                                
                                if (_showInstructions)
                                  SwipeInstructionsOverlay(
                                    onDismiss: _dismissInstructions,
                                    screenSize: MediaQuery.of(context).size,
                                  ),
                              ],
                            ),
                          ),
                                    ),
                                    
                                    // Add Banner Widget
                                    const BannerWidget(),
                                    
                                    // Top Events Section - Vertical Layout for Mobile
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                                      child: Column(
                                        children: [
                                          // Styled Divider with Top Events Text
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  height: 1,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        theme.colorScheme.primary.withOpacity(0.1),
                                                        theme.colorScheme.primary,
                                                        theme.colorScheme.primary.withOpacity(0.1),
                                                      ],
                                                      stops: const [0.0, 0.5, 1.0],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                child: Text(
                                                  'Top Events',
                                                  style: theme.textTheme.titleLarge?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: theme.colorScheme.onBackground,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  height: 1,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        theme.colorScheme.primary.withOpacity(0.1),
                                                        theme.colorScheme.primary,
                                                        theme.colorScheme.primary.withOpacity(0.1),
                                                      ],
                                                      stops: const [0.0, 0.5, 1.0],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 24),
                                          // Vertical List of Events
                                          ...filteredEvents.take(5).map((event) => Padding(
                                            padding: const EdgeInsets.only(bottom: 16),
                                            child: SizedBox(
                                              height: 280,
                                              child: EventListItem(
                                                event: event,
                                                isGridView: true,
                                                onTap: () => context.goNamed(
                                                  'event-details',
                                                  pathParameters: {'eventId': event.id},
                                                ),
                                              ),
                                            ),
                                          )).toList(),
                                        ],
                                      ),
                                    ),
                                  ],
                        );
                      }
                      
                      // For large screens, create a row with side panels
                              return Column(
                                children: [
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height * 0.68,
                                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Center - Event Card
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: SizedBox(
                                width: maxCardWidth,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Stack(
                                  children: [
                                    EventCardStack(
                                      events: filteredEvents,
                                      onSwipe: (event, isRight) {
                                        if (isRight) {
                                          // Capture scaffold messenger before async operation
                                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                                          final eventTitle = event.title;
                                          // Add to favorites
                                          ref.read(favoriteEventsProvider.notifier).favoriteEvent(event.id).then((_) {
                                            // Show success snackbar if still mounted
                                            if (mounted) {
                                              scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                  content: Text('Added $eventTitle to favorites'),
                                                  action: SnackBarAction(
                                                    label: 'UNDO',
                                                    onPressed: () {
                                                      ref.read(favoriteEventsProvider.notifier).unfavoriteEvent(event.id);
                                                    },
                                                  ),
                                                  duration: const Duration(seconds: 3),
                                                ),
                                              );
                                            }
                                          }).catchError((e) {
                                            // Show error snackbar if still mounted
                                            if (mounted) {
                                              scaffoldMessenger.showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed to favorite event: ${e.toString()}'),
                                                  backgroundColor: theme.colorScheme.error,
                                                ),
                                              );
                                            }
                                          });
                                        }
                                      },
                                      onTap: (event) => context.goNamed('event-details', pathParameters: {'eventId': event.id}),
                                      onStackEmpty: () => ref.refresh(eventControllerProvider),
                                    ),
                                    
                                    if (_showInstructions)
                                      SwipeInstructionsOverlay(
                                        onDismiss: _dismissInstructions,
                                        screenSize: MediaQuery.of(context).size,
                                      ),
                                  ],
                                                ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Right panel - Event Tips and Stats
                          SizedBox(
                                          width: 280,
                                          child: SingleChildScrollView(
                                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Padding(
                                              padding: const EdgeInsets.only(left: 16.0, top: 16.0, right: 16.0, bottom: 80.0),
                              child: Column(
                                children: [
                                  // Tips Card
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    color: theme.colorScheme.surface,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.colorScheme.surface,
                                            theme.colorScheme.surface.withOpacity(0.8),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.shadowColor.withOpacity(0.1),
                                            blurRadius: 10,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                        border: Border.all(
                                          color: theme.colorScheme.surfaceVariant,
                                          width: 1.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surfaceVariant,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  Icons.lightbulb_outline, 
                                                  color: Colors.yellow.shade800,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Event Tips',
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          _buildColorfulTipItem(
                                            icon: Icons.swipe_right_alt,
                                            text: 'Swipe right to add to favorites',
                                            theme: theme,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(height: 14),
                                          _buildColorfulTipItem(
                                            icon: Icons.swipe_left_alt,
                                            text: 'Swipe left to skip',
                                            theme: theme,
                                            color: Colors.red,
                                          ),
                                          const SizedBox(height: 14),
                                          _buildColorfulTipItem(
                                            icon: Icons.touch_app,
                                            text: 'Tap to view event details',
                                            theme: theme,
                                            color: Colors.blue,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Stats Card
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    color: theme.colorScheme.surface,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.colorScheme.surface,
                                            theme.colorScheme.surface.withOpacity(0.8),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.shadowColor.withOpacity(0.1),
                                            blurRadius: 10,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                        border: Border.all(
                                          color: theme.colorScheme.surfaceVariant,
                                          width: 1.5,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.surfaceVariant,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(
                                                  Icons.bar_chart, 
                                                  color: Colors.green.shade800,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Event Stats',
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          _buildColorfulStatItem(
                                            label: 'Total Events',
                                            value: '${filteredEvents.length}',
                                            theme: theme,
                                            color: Colors.purple,
                                          ),
                                          const SizedBox(height: 14),
                                          _buildColorfulStatItem(
                                            label: 'Upcoming This Week',
                                            value: '${filteredEvents.where((e) => 
                                              e.startTime.isAfter(DateTime.now()) && 
                                              e.startTime.isBefore(DateTime.now().add(const Duration(days: 7)))
                                            ).length}',
                                            theme: theme,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(height: 14),
                                          _buildColorfulStatItem(
                                            label: 'Free Events',
                                            value: '${filteredEvents.where((e) => e.eventType == EventType.free).length}',
                                            theme: theme,
                                            color: Colors.teal,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  // Google Play Store Button (Web Only)
                                  if (kIsWeb)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16.0),
                                      child: Stack(
                                        alignment: Alignment.centerRight,
                                        children: [
                                          Card(
                                            elevation: 4,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: InkWell(
                                              onTap: () async {
                                                final url = Uri.parse('https://play.google.com/store/apps/details?id=com.packages.scompass&pcampaignid=web_share');
                                                if (await canLaunchUrl(url)) {
                                                  await launchUrl(url, mode: LaunchMode.externalApplication);
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(10),
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [AppTheme.primaryGradientStart, AppTheme.primaryGradientEnd],
                                                    stops: const [0.3, 1.0],
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: theme.shadowColor.withOpacity(0.25),
                                                      blurRadius: 12,
                                                      spreadRadius: 1,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
                                                child: Row(
                                                  children: [
                                                    // Larger logo with shine effect
                                                    Container(
                                                      height: 38,
                                                      width: 38,
                                                      padding: const EdgeInsets.all(2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: SvgPicture.asset(
                                                        'assets/app_icon/vibeswiper.svg',
                                                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    // Text content with adjusted alignment
                                                    Expanded(
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            'GET IT ON',
                                                            style: theme.textTheme.bodySmall?.copyWith(
                                                              color: Colors.white.withOpacity(0.9),
                                                              letterSpacing: 0.5,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            'Google Play',
                                                            style: theme.textTheme.titleMedium?.copyWith(
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.white,
                                                              fontSize: 18,
                                                              letterSpacing: 0.2,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Download icon
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.2),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: const Icon(
                                                        Icons.download_rounded,
                                                        color: Colors.white,
                                                        size: 22,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Add subtle glow effect at the right edge
                                          Positioned(
                                            right: 0,
                                            child: Container(
                                              height: 48,
                                              width: 24,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerRight,
                                                  end: Alignment.centerLeft,
                                                  colors: [
                                                    AppTheme.primaryGradientEnd.withOpacity(0.4),
                                                    AppTheme.primaryGradientEnd.withOpacity(0.0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                                              ),
                              ),
                            ),
                          ),
                        ],
                                    ),
                                  ),
                                  
                                  // Add Banner Widget only for mobile screens
                                  if (!isLargeScreen)
                                    const BannerWidget(),
                                  
                                  // Top Events Section for large screen
                                  Padding(
                                    padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
                                    child: Column(
                                      children: [
                                        // Styled Divider with Top Events Text
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      theme.colorScheme.primary.withOpacity(0.1),
                                                      theme.colorScheme.primary,
                                                      theme.colorScheme.primary.withOpacity(0.1),
                                                    ],
                                                    stops: const [0.0, 0.5, 1.0],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 24),
                                              child: Text(
                                                'Top Events',
                                                style: theme.textTheme.headlineSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onBackground,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Container(
                                                height: 1,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [
                                                      theme.colorScheme.primary.withOpacity(0.1),
                                                      theme.colorScheme.primary,
                                                      theme.colorScheme.primary.withOpacity(0.1),
                                                    ],
                                                    stops: const [0.0, 0.5, 1.0],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        // Top Events Grid for large screen
                                        SizedBox(
                                          height: 320, // Slightly larger height for desktop
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: filteredEvents.length.clamp(0, 6), // Show max 6 items on desktop
                                            itemBuilder: (context, index) {
                                              final event = filteredEvents[index];
                                              return SizedBox(
                                                width: 320, // Slightly larger width for desktop
                                                child: Padding(
                                                  padding: EdgeInsets.only(
                                                    right: index != filteredEvents.length - 1 ? 24 : 0,
                                                  ),
                                                  child: EventListItem(
                                                    event: event,
                                                    isGridView: true,
                                                    onTap: () => context.goNamed(
                                                      'event-details',
                                                      pathParameters: {'eventId': event.id},
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                );
              },
              loading: () => const LoadingWidget(),
              error: (error, stack) => SCompassErrorWidget(
                message: error.toString(),
                onRetry: () => ref.refresh(eventControllerProvider),
              ),
            ),
          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build colorful tip items
  Widget _buildColorfulTipItem({
    required IconData icon,
    required String text,
    required ThemeData theme,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark 
                ? color.withOpacity(0.3) 
                : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  // Helper method to build colorful stat items
  Widget _buildColorfulStatItem({
    required String label,
    required String value,
    required ThemeData theme,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark 
                ? color.withOpacity(0.3) 
                : color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.brightness == Brightness.dark
                  ? color.withAlpha(255)  // Brighter in dark mode
                  : color,
            ),
          ),
        ),
      ],
    );
  }
}
