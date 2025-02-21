import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_participant_model.dart';
import '../controllers/event_participant_controller.dart';

// Providers for participant information
final currentUserProvider = Provider<User?>((ref) {
  return Supabase.instance.client.auth.currentUser;
});

// Keep track of participation status across events
final userParticipationProvider = FutureProvider.autoDispose.family<EventParticipant?, 
    ({String eventId, String userId})>((ref, params) async {
  try {
    debugPrint('Fetching participation status for event: ${params.eventId}, user: ${params.userId}');
    
    final participants = await ref
        .read(eventParticipantControllerProvider.notifier)
        .loadParticipants(params.eventId);
    
    debugPrint('Found ${participants.length} participants for event ${params.eventId}');
    
    if (participants.isNotEmpty) {
      try {
        final participant = participants.firstWhere(
          (p) => p.userId == params.userId,
          orElse: () => throw Exception('Participant not found'),
        );
        
        debugPrint('Found participant status: ${participant.status} for user: ${params.userId}');
        
        // Return the participant if they are accepted
        if (participant.status == ParticipantStatus.accepted) {
          return participant;
        }
      } catch (e) {
        debugPrint('No participant found for user ${params.userId}');
      }
    }
    return null;
  } catch (e) {
    debugPrint('Error fetching participants: $e');
    return null;
  }
});

final participantsCountProvider =
    FutureProvider.family<int, String>((ref, eventId) async {
  final participants = await ref
      .read(eventParticipantControllerProvider.notifier)
      .loadParticipants(eventId);
  return participants.length;
});
