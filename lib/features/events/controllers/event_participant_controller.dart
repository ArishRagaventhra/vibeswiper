import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/event_participant_model.dart';
import '../models/event_admin_log_model.dart';
import '../repositories/event_participant_repository.dart';

final eventParticipantControllerProvider =
    StateNotifierProvider<EventParticipantController, AsyncValue<List<EventParticipant>>>(
  (ref) => EventParticipantController(
    ref.watch(eventParticipantRepositoryProvider),
  ),
);

final eventAdminLogsProvider =
    FutureProvider.family<List<EventAdminLog>, String>((ref, eventId) {
  return ref
      .watch(eventParticipantRepositoryProvider)
      .getEventAdminLogs(eventId);
});

final userRoleProvider =
    FutureProvider.family<ParticipantRole, ({String eventId, String userId})>(
  (ref, params) {
    return ref
        .watch(eventParticipantRepositoryProvider)
        .getUserRole(params.eventId, params.userId);
  },
);

class EventParticipantController
    extends StateNotifier<AsyncValue<List<EventParticipant>>> {
  final EventParticipantRepository _repository;

  EventParticipantController(this._repository)
      : super(const AsyncValue.loading());

  // Load participants for an event
  Future<List<EventParticipant>> loadParticipants(String eventId) async {
    state = const AsyncValue.loading();
    try {
      final participants = await _repository.getEventParticipants(eventId);
      state = AsyncValue.data(participants);
      return participants;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Change participant role
  Future<void> changeRole(
    String eventId,
    String actorId,
    String targetUserId,
    ParticipantRole newRole,
  ) async {
    try {
      await _repository.changeParticipantRole(
        eventId,
        actorId,
        targetUserId,
        newRole,
      );
      await loadParticipants(eventId);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Update participant status
  Future<void> updateStatus(
    String eventId,
    String userId,
    ParticipantStatus newStatus,
  ) async {
    try {
      await _repository.updateParticipantStatus(
        eventId,
        userId,
        newStatus,
      );
      await loadParticipants(eventId);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Join event
  Future<void> joinEvent(String eventId, String userId) async {
    try {
      await _repository.joinEvent(eventId, userId);
      await loadParticipants(eventId);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Leave event
  Future<void> leaveEvent(String eventId, String userId) async {
    try {
      await _repository.leaveEvent(eventId, userId);
      await loadParticipants(eventId);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Check if user has admin privileges
  Future<bool> hasAdminPrivileges(String eventId, String userId) {
    return _repository.hasAdminPrivileges(eventId, userId);
  }

  // Fix creator role if needed
  Future<void> ensureCreatorRole(String eventId) async {
    try {
      await _repository.fixCreatorRole(eventId);
      await loadParticipants(eventId);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  // Watch participants in real-time
  void watchParticipants(String eventId) {
    _repository.streamParticipants(eventId).listen(
      (participants) {
        state = AsyncValue.data(participants);
      },
      onError: (error) {
        state = AsyncValue.error(error, StackTrace.current);
      },
    );
  }
}
