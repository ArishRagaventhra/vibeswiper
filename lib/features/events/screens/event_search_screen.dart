import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/features/events/widgets/filter_bottom_sheet.dart';
import 'package:scompass_07/shared/widgets/bottom_nav_bar.dart';
import 'package:scompass_07/shared/widgets/responsive_scaffold.dart';
import 'package:scompass_07/config/theme.dart';
import '../../../config/routes.dart';
import '../../payments/providers/payment_provider.dart';
import '../models/event_model.dart';
import '../controllers/event_controller.dart';
import '../widgets/event_list_item.dart';
// import '../widgets/event_search_ad_item.dart'; // Ad functionality temporarily disabled
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as math;
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EventSearchScreen extends ConsumerStatefulWidget {
  const EventSearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EventSearchScreen> createState() => _EventSearchScreenState();
}

class _EventSearchScreenState extends ConsumerState<EventSearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  String _searchQuery = '';
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _maxPrice;
  bool _onlyFreeEvents = false;
  bool _isSearchBarFocused = false;
  final _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilters({
    String? category,
    DateTime? startDate,
    DateTime? endDate,
    double? maxPrice,
    bool? onlyFreeEvents,
  }) {
    setState(() {
      if (category != null) _selectedCategory = category;
      if (startDate != null) _startDate = startDate;
      if (endDate != null) _endDate = endDate;
      if (maxPrice != null) _maxPrice = maxPrice;
      if (onlyFreeEvents != null) _onlyFreeEvents = onlyFreeEvents;
    });
  }

  // Helper method to determine the appropriate grid columns based on screen width
  int _getGridColumns(double width) {
    if (width > 1400) return 4;
    if (width > 1000) return 3;
    if (width > 700) return 2;
    return 1;
  }

  // Animation for search bar focus
  void _onSearchFocusChange(bool hasFocus) {
    setState(() {
      _isSearchBarFocused = hasFocus;
    });
    if (hasFocus) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventControllerProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 700;
    final gridColumns = _getGridColumns(size.width);
    final contentPadding = isLargeScreen ? 24.0 : 16.0;

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Animate(
          effects: const [
            FadeEffect(duration: Duration(milliseconds: 600), curve: Curves.easeOutQuad),
            SlideEffect(begin: Offset(-0.2, 0), end: Offset.zero, duration: Duration(milliseconds: 600))
          ],
          child: Text(
            'Explore',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          Animate(
            effects: const [
              FadeEffect(duration: Duration(milliseconds: 800), curve: Curves.easeOutQuad),
              SlideEffect(begin: Offset(0.2, 0), end: Offset.zero, duration: Duration(milliseconds: 800))
            ],
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
                onPressed: () => _showFilterBottomSheet(context),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(contentPadding, 8, contentPadding, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar with animation
                // Search Bar - simplified to ensure it works on web browsers
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isSearchBarFocused
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: _isSearchBarFocused
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 0,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Focus(
                    onFocusChange: _onSearchFocusChange,
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      keyboardType: TextInputType.text,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 15,
                      ),
                      onSubmitted: (value) {
                        // Hide keyboard when search is submitted
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _searchQuery = value.trim();
                        });
                      },
                      cursorColor: theme.colorScheme.primary,
                      cursorWidth: 1.5,
                      decoration: InputDecoration(
                        hintText: 'Search events...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _isSearchBarFocused
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                          size: 22,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  size: 20,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim();
                        });
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Category chips with animation
                SizedBox(
                  height: 40,
                  child: eventsAsync.when(
                    data: (events) {
                      final categories = {'All', ...events.map((e) => e.category ?? 'Other')};
                      return AnimationLimiter(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final category = categories.elementAt(index);
                            final isSelected = category == _selectedCategory || (category == 'All' && _selectedCategory == null);
                            
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                horizontalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() => _selectedCategory = isSelected ? null : (category == 'All' ? null : category));
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected 
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isSelected 
                                                ? theme.colorScheme.primary 
                                                : theme.colorScheme.outlineVariant.withOpacity(0.5),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            category,
                                            style: TextStyle(
                                              color: isSelected 
                                                ? theme.colorScheme.onPrimary 
                                                : theme.colorScheme.onSurfaceVariant,
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Section title with animation
                Animate(
                  effects: const [
                    FadeEffect(
                      delay: Duration(milliseconds: 100),
                      duration: Duration(milliseconds: 700)
                    ),
                    SlideEffect(
                      begin: Offset(-0.1, 0),
                      end: Offset.zero,
                      duration: Duration(milliseconds: 600),
                      curve: Curves.easeOutQuad
                    )
                  ],
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Popular Events',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
              ],
            ),
          ),
          
          // Event list with responsive grid for larger screens
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                final filteredEvents = _filterEvents(events);
                if (filteredEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Animate(
                          effects: const [
                            ScaleEffect(
                              delay: Duration(milliseconds: 100),
                              duration: Duration(milliseconds: 600),
                              curve: Curves.elasticOut
                            )
                          ],
                          child: Icon(
                            Icons.search_off,
                            size: 64,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Animate(
                          effects: const [
                            FadeEffect(
                              delay: Duration(milliseconds: 300),
                              duration: Duration(milliseconds: 500)
                            )
                          ],
                          child: Text(
                            'No events found',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Animate(
                          effects: const [
                            FadeEffect(
                              delay: Duration(milliseconds: 500),
                              duration: Duration(milliseconds: 500)
                            )
                          ],
                          child: Text(
                            'Try adjusting your search or filters',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(eventControllerProvider.notifier).loadEvents();
                  },
                  child: isLargeScreen
                      // Grid view for larger screens
                      ? AnimationLimiter(
                          child: GridView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.all(contentPadding),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridColumns,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: filteredEvents.length,
                            itemBuilder: (context, index) {
                              final event = filteredEvents[index];
                              
                              return AnimationConfiguration.staggeredGrid(
                                position: index,
                                duration: const Duration(milliseconds: 350),
                                columnCount: gridColumns,
                                child: ScaleAnimation(
                                  scale: 0.94,
                                  child: FadeInAnimation(
                                    child: EventListItem(
                                      event: event,
                                      isGridView: true,
                                      onTap: () => context.goNamed('event-details', pathParameters: {'eventId': event.id}),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      // List view for mobile screens
                      : AnimationLimiter(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: contentPadding / 2),
                            itemCount: filteredEvents.length,
                            itemBuilder: (context, index) {
                              final event = filteredEvents[index];
                              
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 350),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: EventListItem(
                                      event: event,
                                      isGridView: false,
                                      onTap: () => context.goNamed('event-details', pathParameters: {'eventId': event.id}),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading events',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Event> _filterEvents(List<Event> events) {
    // Normalize search query by removing extra spaces and converting to lowercase
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    
    return events.where((event) {
      // If no search query, all items match the search
      if (normalizedQuery.isEmpty) {
        final matchesCategory = _selectedCategory == null || 
            (_selectedCategory == 'All') ||
            (event.category?.toLowerCase() == _selectedCategory?.toLowerCase());

        final matchesDateRange = (_startDate == null || event.startTime.isAfter(_startDate!)) &&
            (_endDate == null || event.endTime.isBefore(_endDate!));

        final matchesPrice = _onlyFreeEvents ? 
            (event.ticketPrice == 0 || event.ticketPrice == null) :
            (_maxPrice == null || (event.ticketPrice ?? 0) <= _maxPrice!);

        return matchesCategory && matchesDateRange && matchesPrice;
      }
      
      // Title search with higher priority
      final titleContainsQuery = event.title.toLowerCase().contains(normalizedQuery);
      
      // Description search
      final descriptionContainsQuery = event.description != null ? 
          event.description!.toLowerCase().contains(normalizedQuery) : false;
          
      // Location search
      final locationContainsQuery = event.location != null ? 
          event.location!.toLowerCase().contains(normalizedQuery) : false;
      
      // Category search
      final categoryContainsQuery = event.category != null ? 
          event.category!.toLowerCase().contains(normalizedQuery) : false;
          
      // Any field matches the search query
      final matchesSearch = titleContainsQuery || 
          descriptionContainsQuery || 
          locationContainsQuery || 
          categoryContainsQuery;

      // Category filter
      final matchesCategory = _selectedCategory == null || 
          (_selectedCategory == 'All') ||
          (event.category?.toLowerCase() == _selectedCategory?.toLowerCase());

      // Date range filter
      final matchesDateRange = (_startDate == null || event.startTime.isAfter(_startDate!)) &&
          (_endDate == null || event.endTime.isBefore(_endDate!));

      // Price filter
      final matchesPrice = _onlyFreeEvents ? 
          (event.ticketPrice == 0 || event.ticketPrice == null) :
          (_maxPrice == null || (event.ticketPrice ?? 0) <= _maxPrice!);

      return matchesSearch && matchesCategory && matchesDateRange && matchesPrice;
    }).toList();
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterBottomSheet(
        initialCategory: _selectedCategory,
        initialStartDate: _startDate,
        initialEndDate: _endDate,
        initialMaxPrice: _maxPrice,
        initialOnlyFreeEvents: _onlyFreeEvents,
        onApplyFilters: _applyFilters,
      ),
    );
  }
}
