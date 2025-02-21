import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/features/events/models/event_participant_model.dart';
import '../../../config/supabase_config.dart';
import '../models/event_model.dart';
import '../widgets/event_card_stack.dart';
import '../controllers/event_controller.dart';
import 'package:scompass_07/core/widgets/edge_to_edge_container.dart';

class EventDiscoveryScreen extends ConsumerStatefulWidget {
  const EventDiscoveryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<EventDiscoveryScreen> createState() => _EventDiscoveryScreenState();
}

class _EventDiscoveryScreenState extends ConsumerState<EventDiscoveryScreen> {
  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventControllerProvider);

    return EdgeToEdgeContainer(
      statusBarColor: Theme.of(context).colorScheme.background,
      navigationBarColor: Theme.of(context).colorScheme.background,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Discover Events'),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () {
                // TODO: Show filters bottom sheet
              },
            ),
          ],
        ),
        body: eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return const Center(
                child: Text('No events found'),
              );
            }

            return Column(
              children: [
                const SizedBox(height: 12), // Space between app bar and card
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8), // Small space above bottom nav
                    child: EventCardStack(
                      events: events,
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
                                  backgroundColor: Theme.of(context).colorScheme.error,
                                ),
                              );
                            }
                          }
                        }
                      },
                      onTap: (event) {
                        context.pushNamed(
                          'eventDetails',
                          pathParameters: {'id': event.id},
                        );
                      },
                      onStackEmpty: () {
                        // Show empty state or load more events
                        ref.read(eventControllerProvider.notifier).loadEvents();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8), // Space above action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      onTap: () {
                        // Trigger left swipe programmatically
                      },
                      icon: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 32,
                      ),
                      backgroundColor: Colors.red.withOpacity(0.1),
                    ),
                    _ActionButton(
                      onTap: () {
                        // Trigger right swipe programmatically
                      },
                      icon: const Icon(
                        Icons.check,
                        color: Colors.green,
                        size: 32,
                      ),
                      backgroundColor: Colors.green.withOpacity(0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // Space before bottom nav
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => Center(
            child: Text('Error: $error'),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onTap;
  final Icon icon;
  final Color backgroundColor;

  const _ActionButton({
    Key? key,
    required this.onTap,
    required this.icon,
    required this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: icon,
        ),
      ),
    );
  }
}
