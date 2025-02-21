import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_participant_model.dart';
import '../models/event_admin_log_model.dart';

final eventParticipantRepositoryProvider = Provider<EventParticipantRepository>((ref) {
  return EventParticipantRepository(Supabase.instance.client);
});

class EventParticipantRepository {
  final SupabaseClient _client;
  static const String _participantsTable = 'event_participants';
  static const String _adminLogsTable = 'event_admin_logs';

  EventParticipantRepository(this._client);

  // Fetch participants for an event
  Future<List<EventParticipant>> getEventParticipants(String eventId) async {
    final response = await _client
        .from(_participantsTable)
        .select('''
          *,
          profiles:user_id (
            username,
            full_name,
            avatar_url
          )
        ''')
        .eq('event_id', eventId)
        .order('created_at');

    if (response is! List) {
      throw Exception('Invalid response format');
    }

    return response.map((row) => EventParticipant.fromMap(row)).toList();
  }

  // Get participant role for a specific user in an event
  Future<ParticipantRole> getUserRole(String eventId, String userId) async {
    final response = await _client
        .from(_participantsTable)
        .select('role')
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .single();

    return ParticipantRole.values.firstWhere(
      (r) => r.name == (response['role'] ?? 'attendee'),
      orElse: () => ParticipantRole.attendee,
    );
  }

  // Change participant role
  Future<void> changeParticipantRole(
    String eventId,
    String actorId,
    String targetUserId,
    ParticipantRole newRole,
  ) async {
    await _client.rpc(
      'handle_role_change',
      params: {
        'p_event_id': eventId,
        'p_actor_id': actorId,
        'p_target_user_id': targetUserId,
        'p_new_role': newRole.name,
      },
    );
  }

  // Update participant status
  Future<void> updateParticipantStatus(
    String eventId,
    String userId,
    ParticipantStatus newStatus,
  ) async {
    await _client.rpc(
      'handle_join_request',
      params: {
        'p_event_id': eventId,
        'p_user_id': userId,
        'p_status': newStatus.name,
      },
    );
  }

  // Fetch admin logs for an event
  Future<List<EventAdminLog>> getEventAdminLogs(String eventId) async {
    final response = await _client
        .from(_adminLogsTable)
        .select()
        .eq('event_id', eventId)
        .order('created_at', ascending: false);

    return response.map((row) => EventAdminLog.fromMap(row)).toList();
  }

  // Check if user has admin privileges
  Future<bool> hasAdminPrivileges(String eventId, String userId) async {
    final role = await getUserRole(eventId, userId);
    return role == ParticipantRole.organizer;
  }

  // Join event with automatic role assignment
  Future<void> joinEvent(String eventId, String userId) async {
    // First, get the event details to check creator
    final eventResponse = await _client
        .from('events')
        .select()
        .eq('id', eventId)
        .single();
    
    final isCreator = eventResponse['creator_id'] == userId;
    
    // Join with appropriate role
    await _client.from(_participantsTable).upsert({
      'event_id': eventId,
      'user_id': userId,
      'role': isCreator ? ParticipantRole.organizer.name : ParticipantRole.attendee.name,
      'status': ParticipantStatus.accepted.name,  // Always accepted
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Remove admin logging for now since the table schema is different
    /* await _client.from(_adminLogsTable).insert({
      'event_id': eventId,
      'actor_id': userId,
      'target_user_id': userId,
      'action': isCreator ? 'creator_joined' : 'participant_joined',
      'timestamp': DateTime.now().toIso8601String(),
    }); */
  }

  // Update existing participants to fix creator role
  Future<void> fixCreatorRole(String eventId) async {
    // Get event details
    final eventResponse = await _client
        .from('events')
        .select()
        .eq('id', eventId)
        .single();
    
    final creatorId = eventResponse['creator_id'];
    
    // Update creator's role if they're already a participant
    await _client
        .from(_participantsTable)
        .update({
          'role': ParticipantRole.organizer.name,
          'status': ParticipantStatus.accepted.name,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('event_id', eventId)
        .eq('user_id', creatorId);
  }

  // Leave event
  Future<void> leaveEvent(String eventId, String userId) async {
    final role = await getUserRole(eventId, userId);
    if (role == ParticipantRole.organizer) {
      throw Exception('Event organizer cannot leave the event');
    }

    await _client
        .from(_participantsTable)
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  // Stream participants for real-time updates
  Stream<List<EventParticipant>> streamParticipants(String eventId) {
    return _client
        .from(_participantsTable)
        .stream(primaryKey: ['event_id', 'user_id'])
        .eq('event_id', eventId)
        .map((events) async* {
          final participants = <EventParticipant>[];
          for (final event in events) {
            try {
              // Fetch profile data for each participant
              final profile = await _client
                  .from('profiles')
                  .select()
                  .eq('id', event['user_id'])
                  .single();
              
              // Merge profile data with participant data
              final participantData = Map<String, dynamic>.from(event);
              participantData['profiles'] = profile;
              
              participants.add(EventParticipant.fromMap(participantData));
            } catch (e) {
              print('Error processing participant: $e');
              // Continue processing other participants even if one fails
              continue;
            }
          }
          yield participants;
        })
        .asyncExpand((stream) => stream);
  }
}
