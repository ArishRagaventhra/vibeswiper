import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/config/routes.dart';
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/features/events/controllers/event_controller.dart';
import 'package:scompass_07/features/events/models/event_model.dart';
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
import 'dart:async';
import 'package:scompass_07/core/widgets/edge_to_edge_container.dart';

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

      // Check if the event is paid and the user has a successful payment
      final isPaidEvent = event.eventType == EventType.paid;
      final hasSuccessfulPayment = _checkUserPaymentStatus(event.id);

      return matchesSearch && matchesStatus && matchesCategory && 
             (!isPaidEvent || hasSuccessfulPayment);
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

  bool _checkUserPaymentStatus(String eventId) {
    // Fetch the user's payment history and check if there's a successful payment for the eventId
    final paymentsAsync = ref.read(paymentProvider);
    bool hasSuccessfulPayment = false;
    paymentsAsync.when(
      data: (payments) {
        hasSuccessfulPayment = payments.any((payment) => payment.eventId == eventId && payment.status == 'success');
      },
      loading: () {},
      error: (_, __) {},
    );
    return hasSuccessfulPayment;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? AppTheme.darkBackgroundColor : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;

    return EdgeToEdgeContainer(
      statusBarColor: theme.colorScheme.background,
      navigationBarColor: theme.colorScheme.background,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: appBarColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          toolbarHeight: 72,
          automaticallyImplyLeading: false,
          titleSpacing: 8,
          title: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            child: EventSearchBar(
              onChanged: _onSearch,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: IconButton(
                icon: Icon(
                  Icons.filter_list,
                  size: 24,
                  color: foregroundColor,
                ),
                onPressed: _showFilters,
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? theme.colorScheme.surface
                      : theme.colorScheme.surfaceVariant,
                  fixedSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
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
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: EventCardStack(
                    events: filteredEvents,
                    onSwipe: (event, isRight) async {
                      if (isRight) {
                        try {
                          await ref.read(favoriteEventsProvider.notifier).favoriteEvent(event.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added ${event.title} to favorites'),
                                action: SnackBarAction(
                                  label: 'UNDO',
                                  onPressed: () {
                                    ref.read(favoriteEventsProvider.notifier).unfavoriteEvent(event.id);
                                  },
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to favorite event: ${e.toString()}'),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      }
                    },
                    onTap: (event) => context.goNamed('event-details', pathParameters: {'eventId': event.id}),
                    onStackEmpty: () => ref.refresh(eventControllerProvider),
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
        bottomNavigationBar: const SCompassBottomNavBar(),
      ),
    );
  }
}
