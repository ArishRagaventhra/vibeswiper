import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/features/events/widgets/filter_bottom_sheet.dart';
import 'package:scompass_07/shared/widgets/bottom_nav_bar.dart';
import 'package:scompass_07/config/theme.dart';
import '../../../config/routes.dart';
import '../../payments/providers/payment_provider.dart';
import '../models/event_model.dart';
import '../controllers/event_controller.dart';
import '../widgets/event_list_item.dart';


class EventSearchScreen extends ConsumerStatefulWidget {
  const EventSearchScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EventSearchScreen> createState() => _EventSearchScreenState();
}

class _EventSearchScreenState extends ConsumerState<EventSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  double? _maxPrice;
  bool _onlyFreeEvents = false;
  
  @override
  void dispose() {
    _searchController.dispose();
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

  bool _checkUserPaymentStatus(String eventId) {
    // Watch the payment provider instead of reading it
    final paymentsAsync = ref.watch(paymentProvider);
    return paymentsAsync.when(
      data: (payments) => payments.any((payment) => 
        payment.eventId == eventId && payment.status == 'success'
      ),
      loading: () => false,
      error: (_, __) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Explore',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onBackground,
          ),
        ),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.tune,
              color: theme.colorScheme.primary,
            ),
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search events...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Category chips
                SizedBox(
                  height: 40,
                  child: eventsAsync.when(
                    data: (events) {
                      final categories = {'All', ...events.map((e) => e.category ?? 'Other')};
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = categories.elementAt(index);
                          final isSelected = category == _selectedCategory || (category == 'All' && _selectedCategory == null);
                          return FilterChip(
                            label: Text(category),
                            selected: isSelected,
                            showCheckmark: false,
                            backgroundColor: theme.colorScheme.surfaceVariant,
                            selectedColor: theme.colorScheme.primary,
                            labelStyle: TextStyle(
                              color: isSelected 
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            onSelected: (selected) {
                              setState(() => _selectedCategory = selected ? (category == 'All' ? null : category) : null);
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Results count
                Text(
                  'Popular Events',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          
          // Event list
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                final filteredEvents = _filterEvents(events);
                if (filteredEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No events found',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
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
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];
                      return EventListItem(
                        event: event,
                        onTap: () => context.goNamed('event-details', pathParameters: {'eventId': event.id}),
                      );
                    },
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
      bottomNavigationBar: const SCompassBottomNavBar(),
    );
  }

  List<Event> _filterEvents(List<Event> events) {
    return events.where((event) {
      final matchesSearch = _searchQuery.isEmpty ||
          event.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (event.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          (event.location?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesCategory = _selectedCategory == null ||
          event.category?.toLowerCase() == _selectedCategory?.toLowerCase();

      final matchesDateRange = (_startDate == null || event.startTime.isAfter(_startDate!)) &&
          (_endDate == null || event.endTime.isBefore(_endDate!));

      final matchesPrice = _onlyFreeEvents ? 
          (event.ticketPrice == 0 || event.ticketPrice == null) :
          (_maxPrice == null || (event.ticketPrice ?? 0) <= _maxPrice!);

      final isPaidEvent = event.eventType == EventType.paid;
      final hasSuccessfulPayment = isPaidEvent ? _checkUserPaymentStatus(event.id) : true;

      return matchesSearch && matchesCategory && matchesDateRange && matchesPrice && 
             (!isPaidEvent || hasSuccessfulPayment);
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
