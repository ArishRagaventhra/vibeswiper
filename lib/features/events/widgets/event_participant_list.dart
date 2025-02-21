import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/event_participant_controller.dart';
import '../models/event_admin_log_model.dart';
import '../models/event_participant_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventParticipantList extends ConsumerStatefulWidget {
  final String eventId;
  final bool showAdminControls;

  const EventParticipantList({
    Key? key,
    required this.eventId,
    this.showAdminControls = false,
  }) : super(key: key);

  @override
  ConsumerState<EventParticipantList> createState() =>
      _EventParticipantListState();
}

class _EventParticipantListState extends ConsumerState<EventParticipantList> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(eventParticipantControllerProvider.notifier)
          .watchParticipants(widget.eventId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final participantsState = ref.watch(eventParticipantControllerProvider);
    final currentUser = Supabase.instance.client.auth.currentUser;

    return participantsState.when(
      data: (participants) => ListView.builder(
        shrinkWrap: true,
        itemCount: participants.length,
        itemBuilder: (context, index) {
          final participant = participants[index];
          return ParticipantListTile(
            participant: participant,
            showAdminControls: widget.showAdminControls &&
                currentUser != null &&
                participant.userId != currentUser.id &&
                participant.role != ParticipantRole.organizer, // Can't modify other organizers
            eventId: widget.eventId,
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: ${error.toString()}'),
      ),
    );
  }
}

class ParticipantListTile extends ConsumerWidget {
  final EventParticipant participant;
  final bool showAdminControls;
  final String eventId;

  const ParticipantListTile({
    Key? key,
    required this.participant,
    required this.showAdminControls,
    required this.eventId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: participant.avatarUrl == null 
              ? _getRoleColor(participant.role).withOpacity(0.1)
              : null,
          backgroundImage: participant.avatarUrl != null 
              ? NetworkImage(participant.avatarUrl!) 
              : null,
          child: participant.avatarUrl == null
              ? Text(
                  (participant.fullName?.substring(0, 1) ?? 
                   participant.username?.substring(0, 1) ?? 
                   'U').toUpperCase(),
                  style: TextStyle(
                    color: _getRoleColor(participant.role),
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          participant.fullName ?? participant.username ?? 'Anonymous User',
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${participant.username ?? participant.userId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _getRoleIcon(participant.role),
                  size: 16,
                  color: _getRoleColor(participant.role),
                ),
                const SizedBox(width: 4),
                Text(
                  _getRoleDisplayName(participant.role),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _getRoleColor(participant.role),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusChip(participant.status),
              ],
            ),
          ],
        ),
        trailing: showAdminControls
            ? PopupMenuButton<ParticipantRole>(
                icon: const Icon(Icons.more_vert),
                onSelected: (ParticipantRole newRole) async {
                  if (currentUser != null) {
                    await ref
                        .read(eventParticipantControllerProvider.notifier)
                        .changeRole(
                          eventId,
                          currentUser.id,
                          participant.userId,
                          newRole,
                        );
                  }
                },
                itemBuilder: (BuildContext context) =>
                    ParticipantRole.values.map((role) {
                  return PopupMenuItem<ParticipantRole>(
                    value: role,
                    child: Text(_getRoleDisplayName(role)),
                  );
                }).toList(),
              )
            : null,
      ),
    );
  }

  Widget _buildStatusChip(ParticipantStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getStatusColor(status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusDisplayName(status),
        style: TextStyle(
          color: _getStatusColor(status).computeLuminance() > 0.5
              ? Colors.black87
              : Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getRoleDisplayName(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.organizer:
        return 'Organizer';
      case ParticipantRole.attendee:
        return 'Attendee';
      case ParticipantRole.speaker:
        return 'Speaker';
      case ParticipantRole.volunteer:
        return 'Volunteer';
    }
  }

  IconData _getRoleIcon(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.organizer:
        return Icons.admin_panel_settings;
      case ParticipantRole.attendee:
        return Icons.person;
      case ParticipantRole.speaker:
        return Icons.record_voice_over;
      case ParticipantRole.volunteer:
        return Icons.volunteer_activism;
    }
  }

  Color _getRoleColor(ParticipantRole role) {
    switch (role) {
      case ParticipantRole.organizer:
        return Colors.purple;
      case ParticipantRole.attendee:
        return Colors.blue;
      case ParticipantRole.speaker:
        return Colors.orange;
      case ParticipantRole.volunteer:
        return Colors.green;
    }
  }

  String _getStatusDisplayName(ParticipantStatus status) {
    switch (status) {
      case ParticipantStatus.pending:
        return 'Pending';
      case ParticipantStatus.accepted:
        return 'Accepted';
      case ParticipantStatus.rejected:
        return 'Rejected';
    }
  }

  Color _getStatusColor(ParticipantStatus status) {
    switch (status) {
      case ParticipantStatus.pending:
        return Colors.orange;
      case ParticipantStatus.accepted:
        return Colors.green;
      case ParticipantStatus.rejected:
        return Colors.red;
    }
  }
}

class AdminLogsList extends ConsumerWidget {
  final String eventId;

  const AdminLogsList({Key? key, required this.eventId}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsyncValue = ref.watch(eventAdminLogsProvider(eventId));
    final theme = Theme.of(context);

    return logsAsyncValue.when(
      data: (logs) => logs.isEmpty
          ? Center(
              child: Text(
                'No administrative actions yet',
                style: theme.textTheme.bodyLarge,
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text(
                      'Action: ${_getActionDisplayName(log.actionType)}',
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By: ${log.actorId}'),
                        if (log.targetUserId != null)
                          Text('Target: ${log.targetUserId}'),
                        if (log.notes != null) Text('Notes: ${log.notes}'),
                      ],
                    ),
                    trailing: Text(
                      _formatDateTime(log.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error loading logs: ${error.toString()}'),
      ),
    );
  }

  String _getActionDisplayName(AdminActionType type) {
    switch (type) {
      case AdminActionType.roleChange:
        return 'Role Changed';
      case AdminActionType.statusChange:
        return 'Status Changed';
      case AdminActionType.participantRemoved:
        return 'Participant Removed';
      case AdminActionType.settingsChanged:
        return 'Settings Changed';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.day}/${local.month}/${local.year}\n${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }
}
