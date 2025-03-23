import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../config/theme.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/error_widget.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../../shared/widgets/responsive_scaffold.dart';
import '../../payments/providers/payment_provider.dart';
import '../controllers/event_controller.dart';
import '../models/event_model.dart';
import '../providers/event_search_provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scompass_07/core/widgets/edge_to_edge_container.dart';

final myEventsTabProvider = StateProvider<int>((ref) => 0);

class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedTab = ref.watch(myEventsTabProvider);
    final isDark = theme.brightness == Brightness.dark;
    final tabs = ['Favorites', 'Joined', 'Created'];

    return EdgeToEdgeContainer(
      statusBarColor: theme.colorScheme.background,
      navigationBarColor: theme.colorScheme.background,
      child: DefaultTabController(
        length: tabs.length,
        initialIndex: selectedTab,
        child: ResponsiveScaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            title: Text(
              'My Events',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            centerTitle: false,
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(130),
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? theme.colorScheme.surface 
                            : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          ref.read(eventSearchQueryProvider.notifier).state = value;
                        },
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search events...',
                          hintStyle: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Tab Bar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark 
                            ? theme.colorScheme.surface
                            : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TabBar(
                        onTap: (index) => ref.read(myEventsTabProvider.notifier).state = index,
                        isScrollable: false,
                        labelPadding: EdgeInsets.zero,
                        indicatorPadding: EdgeInsets.zero,
                        padding: const EdgeInsets.all(4),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicatorColor: Colors.transparent,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        labelColor: isDark ? Colors.black : Colors.white,
                        unselectedLabelColor: isDark 
                            ? Colors.white.withOpacity(0.8)
                            : Colors.black.withOpacity(0.8),
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        tabs: tabs.map((tab) {
                          return SizedBox(
                            height: 40,
                            child: Center(
                              child: Text(
                                tab,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(), // Disable swipe
            children: [
              _FavoriteEventsTab(),
              _JoinedEventsTab(),
              _CreatedEventsTab(),
            ],
          ),
        ),
      ),
    );
  }

  bool _checkUserPaymentStatus(String eventId, WidgetRef ref) {
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
}

class _JoinedEventsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(joinedEventsProvider);
    final query = ref.watch(eventSearchQueryProvider);

    return eventsAsync.when(
      data: (events) {
        final filteredEvents = ref.watch(filteredEventsProvider(events));

        return filteredEvents.isEmpty
            ? _buildEmptyState(
                query.isEmpty ? 'No joined events yet' : 'No events found matching "$query"',
                query.isEmpty ? Icons.group_outlined : Icons.search_off_rounded,
              )
            : _buildEventsList(context, filteredEvents, 'joined');
      },
      loading: () => const LoadingWidget(),
      error: (error, stack) => SCompassErrorWidget(
        message: error.toString(),
        onRetry: () => ref.refresh(joinedEventsProvider),
      ),
    );
  }
}

class _CreatedEventsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(createdEventsProvider);
    final query = ref.watch(eventSearchQueryProvider);

    return eventsAsync.when(
      data: (events) {
        final filteredEvents = ref.watch(filteredEventsProvider(events));

        return filteredEvents.isEmpty
            ? _buildEmptyState(
                query.isEmpty ? 'No created events yet' : 'No events found matching "$query"',
                query.isEmpty ? Icons.add_circle_outline : Icons.search_off_rounded,
              )
            : _buildEventsList(context, filteredEvents, 'created');
      },
      loading: () => const LoadingWidget(),
      error: (error, stack) => SCompassErrorWidget(
        message: error.toString(),
        onRetry: () => ref.refresh(createdEventsProvider),
      ),
    );
  }
}

class _FavoriteEventsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(favoriteEventsProvider);
    final query = ref.watch(eventSearchQueryProvider);

    return eventsAsync.when(
      data: (events) {
        final filteredEvents = ref.watch(filteredEventsProvider(events));
        return filteredEvents.isEmpty
            ? _buildEmptyState(
                query.isEmpty ? 'No favorite events yet' : 'No events found matching "$query"',
                query.isEmpty ? Icons.favorite_border : Icons.search_off_rounded,
              )
            : _buildEventsList(context, filteredEvents, 'favorite');
      },
      loading: () => const LoadingWidget(),
      error: (error, stack) => SCompassErrorWidget(
        message: error.toString(),
        onRetry: () => ref.refresh(favoriteEventsProvider),
      ),
    );
  }
}

Widget _buildEmptyState(String message, IconData icon) {
  return Builder(
    builder: (context) => Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    ),
  );
}

Color _getStatusColor(BuildContext context, EventStatus status) {
  switch (status) {
    case EventStatus.draft:
      return Theme.of(context).colorScheme.surfaceContainerLowest;
    case EventStatus.upcoming:
      return Theme.of(context).colorScheme.primary;
    case EventStatus.ongoing:
      return Theme.of(context).colorScheme.secondary;
    case EventStatus.completed:
      return Theme.of(context).colorScheme.surfaceContainerHighest;
    case EventStatus.cancelled:
      return Theme.of(context).colorScheme.error;
  }
}

Widget _buildEventsList(BuildContext context, List<Event> events, String type) {
  return AnimationLimiter(
    child: ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return AnimationConfiguration.staggeredList(
          position: index,
          duration: const Duration(milliseconds: 375),
          child: SlideAnimation(
            verticalOffset: 50.0,
            child: FadeInAnimation(
              child: GestureDetector(
                onTap: () {
                  // Delay the navigation to avoid state modification during build
                  Future(() {
                    context.go('/events/${event.id}');
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        // Event Image
                        if (event.mediaUrls?.isNotEmpty ?? false)
                          CachedNetworkImage(
                            imageUrl: event.mediaUrls!.first,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              height: 200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              height: 200,
                              child: const Icon(Icons.error),
                            ),
                          ),
                        // Gradient Overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Event Details
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(context, event.currentStatus).withOpacity(0.2),
                                            border: Border.all(
                                              color: _getStatusColor(context, event.currentStatus).withOpacity(0.5),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            event.eventType.name.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(context, event.currentStatus).withOpacity(0.2),
                                            border: Border.all(
                                              color: _getStatusColor(context, event.currentStatus).withOpacity(0.5),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            event.currentStatus.name.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (type == 'favorite')
                                      Consumer(
                                        builder: (context, ref, child) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.7),
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.favorite,
                                                color: Colors.red,
                                                size: 22,
                                              ),
                                              onPressed: () {
                                                ref.read(favoriteEventsProvider.notifier).unfavoriteEvent(event.id);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(
                                                    content: Text('Event removed from favorites'),
                                                    duration: Duration(seconds: 2),
                                                  ),
                                                );
                                              },
                                              padding: const EdgeInsets.all(8),
                                              constraints: const BoxConstraints(),
                                              splashRadius: 24,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  event.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${event.startTime.day}/${event.startTime.month}/${event.startTime.year}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (event.location != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: Colors.white70,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          event.location!,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
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
}
