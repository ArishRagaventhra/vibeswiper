import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as filepath;
import '../../../config/supabase_config.dart';
import '../models/event_model.dart';
import '../models/event_participant_model.dart';
import '../models/event_action_model.dart';
import '../repositories/event_repository.dart';
import '../utils/media_utils.dart';

final eventControllerProvider = StateNotifierProvider<EventController, AsyncValue<List<Event>>>(
  (ref) => EventController(
    repository: ref.watch(eventRepositoryProvider),
  ),
);

final userEventsProvider = FutureProvider.family<List<Event>, String>(
  (ref, userId) => ref.watch(eventRepositoryProvider).getUserEvents(userId),
);

final eventDetailsProvider = FutureProvider.family<Event?, String>(
  (ref, eventId) => ref.watch(eventRepositoryProvider).getEventById(eventId),
);

final eventParticipantsProvider = FutureProvider.family<List<EventParticipant>, String>(
  (ref, eventId) => ref.watch(eventRepositoryProvider).getEventParticipants(eventId),
);

// Providers for My Events screen
final savedEventsProvider = AsyncNotifierProvider<SavedEventsController, List<Event>>(
  SavedEventsController.new,
);

final joinedEventsProvider = AsyncNotifierProvider<JoinedEventsController, List<Event>>(
  JoinedEventsController.new,
);

final createdEventsProvider = AsyncNotifierProvider<CreatedEventsController, List<Event>>(
  CreatedEventsController.new,
);

final favoriteEventsProvider = AsyncNotifierProvider<FavoriteEventsController, List<Event>>(
  FavoriteEventsController.new,
);

class EventController extends StateNotifier<AsyncValue<List<Event>>> {
  final EventRepository _repository;
  static const String _eventMediaBucket = 'event-media';

  EventController({required EventRepository repository})
      : _repository = repository,
        super(const AsyncValue.data([])) {
    loadEvents();
  }

  Future<void> loadEvents({
    String? category,
    EventStatus? status,
    EventVisibility? visibility,
    String? creatorId,
    DateTime? startAfter,
    DateTime? endBefore,
  }) async {
    if (!mounted) return;
    
    try {
      state = const AsyncValue.loading();
      final events = await _repository.getEvents(
        category: category,
        status: status,
        visibility: visibility,
        creatorId: creatorId,
        startAfter: startAfter,
        endBefore: endBefore,
      );
      
      if (!mounted) return;
      
      // Filter out cancelled and deleted events
      final filteredEvents = events.where((event) => 
        event.status != EventStatus.cancelled && 
        event.deletedAt == null
      ).toList();
      
      state = AsyncValue.data(filteredEvents);
    } catch (err, stack) {
      if (!mounted) return;
      state = AsyncValue.error(err, stack);
    }
  }

  Future<Event?> updateEvent(Event event) async {
    try {
      // Convert event to map and remove computed fields
      final eventData = event.toMap();
      eventData.remove('likes_count');
      eventData.remove('saves_count');
      eventData.remove('participants_count');
      eventData.remove('favorites_count');
      
      // Ensure arrays are initialized
      eventData['media_urls'] = eventData['media_urls'] ?? [];
      eventData['tags'] = eventData['tags'] ?? [];
      
      // Convert enums to strings
      eventData['status'] = event.status.name;
      eventData['event_type'] = event.eventType.name;
      eventData['visibility'] = event.visibility.name;
      
      // Remove any null values
      eventData.removeWhere((key, value) => value == null);
      
      final updatedEvent = await _repository.updateEvent(event.id, eventData);
      if (updatedEvent != null) {
        // Update the state with the new event
        state.whenData((events) {
          final index = events.indexWhere((e) => e.id == event.id);
          if (index != -1) {
            final updatedEvents = List<Event>.from(events);
            updatedEvents[index] = updatedEvent;
            state = AsyncValue.data(updatedEvents);
          }
        });
      }
      return updatedEvent;
    } catch (e) {
      debugPrint('Error updating event: $e');
      return null;
    }
  }

  Future<Event?> createEventWithMedia({
    required String title,
    required String creatorId,
    String? description,
    String? location,
    required DateTime startTime,
    required DateTime endTime,
    required EventType eventType,
    required EventVisibility visibility,
    int? maxParticipants,
    String? category,
    List<String>? tags,
    String? recurringPattern,
    Duration? reminderBefore,
    DateTime? registrationDeadline,
    double? ticketPrice,
    double? vibePrice,
    String? currency,
    required List<XFile> mediaFiles,
    String? accessCode,
  }) async {
    final eventId = const Uuid().v4();
    try {
      debugPrint('Creating event $eventId with ${mediaFiles.length} media files');

      // Upload media files first
      final mediaUrls = await uploadEventMediaBatch(mediaFiles, eventId);
      debugPrint('Media upload complete. URLs: $mediaUrls');

      if (mediaUrls.isEmpty && mediaFiles.isNotEmpty) {
        throw Exception('Failed to upload media files');
      }

      final now = DateTime.now().toUtc();

      // Use a transaction function to create event WITHOUT creating chat room
      // This ensures chat room is only created during finalization
      try {
        final response = await SupabaseConfig.client
            .from('events')
            .insert({
              'id': eventId,
              'title': title,
              'creator_id': creatorId,
              'description': description,
              'location': location,
              'start_time': startTime.toIso8601String(),
              'end_time': endTime.toIso8601String(),
              'event_type': eventType.toString().split('.').last,
              'visibility': visibility.toString().split('.').last,
              'max_participants': maxParticipants,
              'category': category,
              'tags': tags,
              'recurring_pattern': recurringPattern,
              'reminder_before': reminderBefore?.inMinutes,
              'registration_deadline': registrationDeadline?.toIso8601String(),
              'ticket_price': ticketPrice,
              'vibe_price': vibePrice,
              'currency': currency,
              'media_urls': mediaUrls,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
              'access_code': accessCode,
              'status': EventStatus.draft.toString().split('.').last,
              'is_platform_fee_paid': false,
            })
            .select()
            .single();

        // Enhanced debugging
        debugPrint('Event created: $eventId');

        // Fetch the event details using the event_id
        final eventDetails = await _repository.getEventById(eventId);
        if (eventDetails == null) {
          throw Exception('Failed to fetch created event details');
        }

        // Update our state with the newly created event
        state.whenData((events) {
          state = AsyncValue.data([...events, eventDetails]);
        });

        return eventDetails;
      } catch (e) {
        // Log the specific error
        debugPrint('Error creating event: $e');
        rethrow;
      }
    } catch (e, stackTrace) {
      debugPrint('Error creating event: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Clean up uploaded media if event creation fails
      if (mediaFiles.isNotEmpty) {
        try {
          await _repository.deleteEventMedia(eventId);
        } catch (cleanupError) {
          debugPrint('Error cleaning up media after failed event creation: $cleanupError');
        }
      }
      
      rethrow;
    }
  }

  Future<List<String>> uploadEventMediaBatch(List<XFile> files, String eventId) async {
    try {
      debugPrint('Processing ${files.length} files for upload');
      List<String> errors = [];

      // Process all files in parallel
      final processedMediaFutures = files.map((file) async {
        try {
          debugPrint('Processing file for upload: ${file.path}');
          return await MediaUtils.processMediaFile(file);
        } catch (e) {
          debugPrint('Error processing file ${file.path}: $e');
          errors.add('Failed to process ${file.path}: $e');
          return null;
        }
      });

      // Wait for all files to be processed
      final processedMediaList = await Future.wait(processedMediaFutures);
      final validMediaList = processedMediaList.where((media) => media != null).toList();

      if (validMediaList.isEmpty && files.isNotEmpty) {
        throw Exception('No valid media files to upload. Errors: ${errors.join(", ")}');
      }

      // Upload all processed files in parallel
      final uploadFutures = validMediaList.map((processedMedia) async {
        if (processedMedia == null) return null;
        try {
          return await uploadEventMedia(processedMedia.file, eventId, processedMedia.mimeType);
        } catch (e) {
          debugPrint('Error uploading file ${processedMedia.file.path}: $e');
          errors.add('Failed to upload ${processedMedia.file.path}: $e');
          return null;
        }
      });

      // Wait for all uploads to complete
      final mediaUrls = (await Future.wait(uploadFutures))
          .where((url) => url != null)
          .map((url) => url!)
          .toList();

      if (errors.isNotEmpty) {
        debugPrint('Some files failed to upload: ${errors.join(", ")}');
      }

      return mediaUrls;
    } catch (e) {
      debugPrint('Error in uploadEventMediaBatch: $e');
      rethrow;
    }
  }

  Future<String?> uploadEventMedia(XFile file, String eventId, String mimeType) async {
    try {
      debugPrint('Starting upload for file: ${file.path} with MIME type: $mimeType');
      final bytes = await file.readAsBytes();
      final fileExt = filepath.extension(file.path).toLowerCase();
      final fileName = '${eventId}_${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final storagePath = '$eventId/$fileName';

      // Get content type for upload
      final contentType = MediaUtils.getMediaContentType(mimeType);
      debugPrint('Using content type: ${contentType.toString()}');

      // Upload the file with content type
      await SupabaseConfig.client.storage
          .from(_eventMediaBucket)
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType.toString(),
            ),
          );

      debugPrint('File uploaded successfully to path: $storagePath');

      // Get the public URL
      final urlResponse = SupabaseConfig.client.storage
          .from(_eventMediaBucket)
          .getPublicUrl(storagePath);

      debugPrint('Generated public URL: $urlResponse');
      return urlResponse;
    } catch (e) {
      debugPrint('Error uploading media: $e');
      return null;
    }
  }

  Future<void> favoriteEvent(String eventId, bool isFavorited) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final userId = SupabaseConfig.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      if (isFavorited) {
        await _repository.favoriteEvent(userId, eventId);
      } else {
        await _repository.unfavoriteEvent(userId, eventId);
      }
      final events = await _repository.getEvents();
      return events;
    });
  }

  Future<bool> joinPrivateEvent(String eventId, String accessCode) async {
    state = const AsyncValue.loading();
    try {
      final success = await _repository.joinPrivateEvent(eventId, accessCode);
      if (success) {
        // Refresh events list to update UI
        final events = await _repository.getEvents();
        state = AsyncValue.data(events);
      }
      return success;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      // Restore previous state if there was an error
      if (state.hasError) {
        final events = await _repository.getEvents();
        state = AsyncValue.data(events);
      }
    }
  }

  Future<void> updateEventAccessCode(String eventId, String accessCode) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateEventAccessCode(eventId, accessCode);
      // Refresh events list to update UI
      final events = await _repository.getEvents();
      state = AsyncValue.data(events);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    } finally {
      // Restore previous state if there was an error
      if (state.hasError) {
        final events = await _repository.getEvents();
        state = AsyncValue.data(events);
      }
    }
  }

  Future<Event?> cancelEvent(String eventId, String reason) async {
    try {
      final event = await _repository.cancelEvent(eventId, reason);
      
      if (event != null) {
        // Update the state to reflect the cancelled event
        state.whenData((events) {
          final index = events.indexWhere((e) => e.id == eventId);
          if (index != -1) {
            final updatedEvents = List<Event>.from(events);
            updatedEvents[index] = event;
            state = AsyncValue.data(updatedEvents);
          }
        });
      }
      
      return event;
    } catch (e) {
      debugPrint('Error in controller while cancelling event: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId, String reason) async {
    try {
      state = const AsyncValue.loading();
      
      // Get current event
      final currentEvent = await _repository.getEventById(eventId);
      if (currentEvent == null) {
        throw Exception('Event not found');
      }
      
      // Check if current user is the event creator
      final currentUserId = SupabaseConfig.client.auth.currentUser?.id;
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }
      if (currentEvent.creatorId != currentUserId) {
        throw Exception('Only the event creator can delete this event');
      }
      
      // Calculate deletion date (1 week from now)
      final deletionDate = DateTime.now().add(const Duration(days: 7));
      
      // Update event with deletion date and reason
      await SupabaseConfig.client.from('events').update({
        'deleted_at': deletionDate.toIso8601String(),
        'cancellation_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', eventId);

      // Create event action record
      final actionId = const Uuid().v4();
      final action = EventAction(
        id: actionId,
        eventId: eventId,
        userId: currentUserId,
        actionType: EventActionType.deleted,
        reason: reason,
        createdAt: DateTime.now(),
      );

      await SupabaseConfig.client.from('event_actions').insert(action.toJson());

      // Reload events to update the UI
      await loadEvents();
      
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  // Other methods remain unchanged...
}

class SavedEventsController extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return [];
    return ref.watch(eventRepositoryProvider).getSavedEvents(userId);
  }

  Future<void> saveEvent(String eventId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    await ref.watch(eventRepositoryProvider).saveEvent(eventId, userId);
    ref.invalidateSelf();
  }

  Future<void> unsaveEvent(String eventId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    await ref.watch(eventRepositoryProvider).unsaveEvent(eventId, userId);
    ref.invalidateSelf();
  }

  Future<bool> isEventSaved(String eventId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;
    return ref.watch(eventRepositoryProvider).isEventSaved(eventId, userId);
  }
}

class JoinedEventsController extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return [];
    return ref.watch(eventRepositoryProvider).getJoinedEvents(userId);
  }
}

class CreatedEventsController extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return [];
    return ref.watch(eventRepositoryProvider).getCreatedEvents(userId);
  }
}

class FavoriteEventsController extends AsyncNotifier<List<Event>> {
  @override
  Future<List<Event>> build() async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return [];
    return ref.watch(eventRepositoryProvider).getFavoriteEvents(userId);
  }

  Future<void> favoriteEvent(String eventId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    await ref.watch(eventRepositoryProvider).favoriteEvent(userId, eventId);
    ref.invalidateSelf();
  }

  Future<void> unfavoriteEvent(String eventId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return;
    await ref.watch(eventRepositoryProvider).unfavoriteEvent(userId, eventId);
    ref.invalidateSelf();
  }

  Future<bool> isEventFavorited(String eventId) async {
    final userId = SupabaseConfig.client.auth.currentUser?.id;
    if (userId == null) return false;
    return ref.watch(eventRepositoryProvider).isEventFavorited(eventId, userId);
  }
}
