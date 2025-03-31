import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/app_bar.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../models/event_model.dart';
import '../models/event_participant_model.dart';
import '../controllers/event_controller.dart';
import '../../../core/widgets/edge_to_edge_container.dart';
import '../chat/screens/payment_analytics_screen.dart';

class EventOrganizerDashboard extends ConsumerStatefulWidget {
  final String eventId;

  const EventOrganizerDashboard({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  ConsumerState<EventOrganizerDashboard> createState() => _EventOrganizerDashboardState();
}

class _EventOrganizerDashboardState extends ConsumerState<EventOrganizerDashboard> {
  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));
    final participantsAsync = ref.watch(eventParticipantsProvider(widget.eventId));
    final theme = Theme.of(context);

    return EdgeToEdgeContainer(
      statusBarColor: theme.colorScheme.background,
      navigationBarColor: theme.colorScheme.background,
      child: Scaffold(
        appBar: SCompassAppBar(
          title: 'Event Dashboard',
          centerTitle: false,
          showBackButton: true,
        ),
        body: eventAsync.when(
          data: (event) => participantsAsync.when(
            data: (participants) => _buildDashboard(context, event!, participants),
            loading: () => const LoadingWidget(),
            error: (error, _) => Center(
              child: Text('Error loading participants: $error'),
            ),
          ),
          loading: () => const LoadingWidget(),
          error: (error, _) => Center(
            child: Text('Error loading event: $error'),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, Event event, List<EventParticipant> participants) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final totalParticipants = participants.length;
    final isSmallScreen = size.width < 360;
    final padding = isSmallScreen ? 16.0 : 20.0;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          ref.refresh(eventDetailsProvider(widget.eventId).future),
          ref.refresh(eventParticipantsProvider(widget.eventId).future),
        ]);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Event Header
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(padding),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Organized by you',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Total Participants Card
          SliverPadding(
            padding: EdgeInsets.all(padding),
            sliver: SliverToBoxAdapter(
              child: _buildStatCard(
                context,
                'Total Participants',
                totalParticipants.toString(),
                Icons.group_outlined,
                const Color(0xFFE91E63), // Pink
              ),
            ),
          ),

          // Quick Actions Section
          SliverPadding(
            padding: EdgeInsets.all(padding),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: theme.shadowColor.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildActionTile(
                          context,
                          'View Participants',
                          'Manage event participants',
                          Icons.group_outlined,
                          const Color(0xFF4CAF50), // Green
                          () => context.push('/events/${event.id}/participants'),
                        ),
                        Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
                        _buildActionTile(
                          context,
                          'View Responses',
                          'Check participant responses',
                          Icons.question_answer_outlined,
                          const Color(0xFFFF9800), // Orange
                          () => context.push('/events/${event.id}/responses'),
                        ),
                        Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
                        _buildActionTile(
                          context,
                          'Edit Event',
                          'Modify event details',
                          Icons.edit_outlined,
                          const Color(0xFF2196F3), // Blue
                          () => context.push('/events/${event.id}/edit'),
                        ),
                        Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
                        _buildActionTile(
                          context,
                          'Payment Analytics',
                          'Track payment interactions and scans',
                          Icons.analytics_outlined,
                          const Color(0xFF9C27B0), // Purple
                          () {
                            context.go(
                              '/events/${event.id}/payment-analytics',
                              extra: event.title,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Danger Zone Section
          SliverPadding(
            padding: EdgeInsets.all(padding),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Danger Zone',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.error.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildActionTile(
                          context,
                          'Cancel Event',
                          'Cancel this event',
                          Icons.cancel_outlined,
                          const Color(0xFFf44336), // Red
                          () => _showCancelEventDialog(context),
                          isDestructive: true,
                        ),
                        Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
                        _buildActionTile(
                          context,
                          'Delete Event',
                          'This action cannot be undone',
                          Icons.delete_outline,
                          const Color(0xFFf44336), // Red
                          () => _showDeleteEventDialog(context, event),
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Padding
          SliverPadding(padding: EdgeInsets.only(bottom: padding * 2)),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
            ),
            SizedBox(width: isSmallScreen ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    final theme = Theme.of(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
              decoration: BoxDecoration(
                color: (isDestructive ? theme.colorScheme.error : color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isDestructive ? theme.colorScheme.error : color,
                size: isSmallScreen ? 20 : 24,
              ),
            ),
            SizedBox(width: isSmallScreen ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: (isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant).withOpacity(0.5),
              size: isSmallScreen ? 20 : 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelEventDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Event'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to cancel this event?',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for cancellation',
                  hintText: 'Please provide a detailed reason',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'Please provide a reason with at least 10 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep Event'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final reason = reasonController.text.trim();
              
              // Close the dialog first
              navigator.pop();
              
              try {
                // Show loading indicator
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Cancelling event...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                await ref
                    .read(eventControllerProvider.notifier)
                    .cancelEvent(widget.eventId, reason);

                if (!mounted) return;

                // Clear previous snackbars and show success
                scaffoldMessenger
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Event cancelled successfully',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );

                // Navigate back after a short delay
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    context.go('/events');
                  }
                });
              } catch (e) {
                if (!mounted) return;
                // Only show error if it's not related to notifications
                if (!e.toString().contains('notifications')) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel event: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Yes, Cancel Event'),
          ),
        ],
      ),
    );
  }

  void _showDeleteEventDialog(BuildContext context, Event event) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this event? '
                'This action cannot be undone.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for deletion',
                  hintText: 'Please provide a detailed reason',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().length < 10) {
                    return 'Please provide a reason with at least 10 characters';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep Event'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }
              
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final reason = reasonController.text.trim();
              
              // Close the dialog first
              navigator.pop();
              
              try {
                // Show loading indicator
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Deleting event...'),
                    duration: Duration(seconds: 1),
                  ),
                );

                await ref
                    .read(eventControllerProvider.notifier)
                    .deleteEvent(widget.eventId, reason);

                // Immediately invalidate the created events list to update UI
                ref.invalidate(createdEventsProvider);

                if (!mounted) return;

                // Clear previous snackbars and show success
                scaffoldMessenger
                  ..clearSnackBars()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Event deleted successfully. It will be permanently removed after 7 days.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );

                // Navigate back after a short delay
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    context.go('/events');
                  }
                });
              } catch (e) {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete event: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Yes, Delete Event'),
          ),
        ],
      ),
    );
  }
}
