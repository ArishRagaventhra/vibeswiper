import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/supabase_config.dart';
import '../models/event_model.dart';
import '../models/event_participant_model.dart';

final eventRepositoryProvider = Provider((ref) => EventRepository(
      supabase: Supabase.instance.client,
    ));

class EventRepository {
  final SupabaseClient _supabase;
  static const String _eventsTable = 'events';
  static const String _participantsTable = 'event_participants';
  static const String _savedEventsTable = 'saved_events';
  static const String _favoriteEventsTable = 'favorite_events';
  static const String _eventImagesBucket = SupabaseConfig.eventImagesBucket;

  EventRepository({required SupabaseClient supabase}) : _supabase = supabase;

  // Create a new event
  Future<Event> createEvent(Event event) async {
    try {
      debugPrint('Creating event with data: ${event.toMap()}');
      final eventData = event.toMap();
      
      // Remove any fields that might not be in the database yet
      eventData.remove('likes_count');
      eventData.remove('saves_count');
      eventData.remove('participants_count');
      eventData.remove('favorites_count');
      
      // Ensure arrays are initialized
      eventData['media_urls'] = eventData['media_urls'] ?? [];
      eventData['tags'] = eventData['tags'] ?? [];
      
      // Ensure status is set to a valid string value
      eventData['status'] = event.status.name;
      
      // Remove any null values
      eventData.removeWhere((key, value) => value == null);
      
      final response = await _supabase
          .from(_eventsTable)
          .insert(eventData)
          .select()
          .single();

      debugPrint('Event created successfully: $response');
      return Event.fromMap(response);
    } catch (e, stackTrace) {
      debugPrint('Error creating event: $e');
      debugPrint(stackTrace.toString());
      rethrow;
    }
  }

  // Get all events (with filters)
  Future<List<Event>> getEvents({
    String? category,
    EventStatus? status,
    EventVisibility? visibility,
    String? creatorId,
    DateTime? startAfter,
    DateTime? endBefore,
  }) async {
    var query = _supabase.from(_eventsTable).select();

    if (category != null) {
      query = query.eq('category', category);
    }
    if (visibility != null) {
      query = query.eq('visibility', visibility.name);
    }
    if (creatorId != null) {
      query = query.eq('creator_id', creatorId);
    }
    
    // Handle date-based filtering
    final now = DateTime.now();
    if (status != null) {
      switch (status) {
        case EventStatus.draft:
          query = query.eq('status', status.name);
          break;
        case EventStatus.upcoming:
          query = query.gt('start_time', now.toIso8601String());
          break;
        case EventStatus.ongoing:
          query = query
            .lte('start_time', now.toIso8601String())
            .gte('end_time', now.toIso8601String());
          break;
        case EventStatus.completed:
          query = query.lt('end_time', now.toIso8601String());
          break;
        case EventStatus.cancelled:
          query = query.eq('status', status.name);
          break;
      }
    }
    
    if (startAfter != null) {
      query = query.gte('start_time', startAfter.toIso8601String());
    }
    if (endBefore != null) {
      query = query.lte('end_time', endBefore.toIso8601String());
    }

    final response = await query;
    return response.map((data) => Event.fromMap(data)).toList();
  }

  // Get a single event by ID
  Future<Event?> getEventById(String eventId) async {
    try {
      // Clean the event ID by removing ALL whitespace
      final cleanEventId = eventId.replaceAll(RegExp(r'\s+'), '');
      debugPrint('Fetching event with cleaned ID: $cleanEventId (original: $eventId)');
      
      // First try direct query
      var response = await _supabase
          .from(_eventsTable)
          .select()
          .eq('id', cleanEventId)
          .maybeSingle();
      
      // If not found, try with original ID as fallback
      if (response == null && cleanEventId != eventId) {
        debugPrint('Event not found with cleaned ID, trying original ID');
        response = await _supabase
            .from(_eventsTable)
            .select()
            .eq('id', eventId)
            .maybeSingle();
      }
      
      debugPrint('Event query response: $response');
      
      if (response == null) {
        debugPrint('No event found with either cleaned ID or original ID');
        return null;
      }
      
      final event = Event.fromMap(response);
      debugPrint('Successfully parsed event: ${event.title}');
      return event;
    } catch (e, stack) {
      debugPrint('Error fetching event: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

  // Update an event
  Future<Event?> updateEvent(String eventId, Map<String, dynamic> data) async {
    try {
      final response = await _supabase
          .from('events')
          .update(data)
          .eq('id', eventId)
          .select()
          .single();
      return Event.fromMap(response);
    } catch (e) {
      print('Error updating event: $e');
      return null;
    }
  }

  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    await _supabase.from(_eventsTable).delete().eq('id', eventId);
  }

  // Cancel an event
  Future<Event?> cancelEvent(String eventId, String reason) async {
    try {
      final data = {
        'status': EventStatus.cancelled.name,
        'cancellation_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from(_eventsTable)
          .update(data)
          .eq('id', eventId)
          .select()
          .single();
          
      return Event.fromMap(response);
    } catch (e) {
      debugPrint('Error cancelling event: $e');
      return null;
    }
  }

  // Participant Management
  Future<EventParticipant> addParticipant(EventParticipant participant) async {
    final response = await _supabase
        .from(_participantsTable)
        .insert(participant.toMap())
        .select();
    return EventParticipant.fromMap(response.first);
  }

  Future<List<EventParticipant>> getEventParticipants(String eventId) async {
    final response = await _supabase
        .from(_participantsTable)
        .select()
        .eq('event_id', eventId);
    return response.map((data) => EventParticipant.fromMap(data)).toList();
  }

  Future<void> updateParticipantStatus(
    String eventId,
    String userId,
    ParticipantStatus status,
  ) async {
    await _supabase
        .from(_participantsTable)
        .update({'status': status.name})
        .match({'event_id': eventId, 'user_id': userId});
  }

  Future<void> removeParticipant(String eventId, String userId) async {
    await _supabase
        .from(_participantsTable)
        .delete()
        .match({'event_id': eventId, 'user_id': userId});
  }

  // Media Management
  Future<void> uploadEventMedia(String path, XFile file) async {
    try {
      debugPrint('Uploading media to path: $path');
      
      // Get the file extension in lowercase, handling cases with no extension
      final String ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      
      // More robust MIME type detection
      String mimeType;
      switch (ext) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        case 'avif':
          mimeType = 'image/avif';
          break;
        case 'mp4':
          mimeType = 'video/mp4';
          break;
        case 'mov':
          mimeType = 'video/quicktime';
          break;
        default:
          mimeType = 'image/jpeg'; // Default to JPEG for unknown types
      }
      
      debugPrint('Detected MIME type: $mimeType for file: ${file.name}');
      
      final bucket = _supabase.storage.from(_eventImagesBucket);
      
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await bucket.uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: mimeType,
          ),
        );
      } else {
        await bucket.upload(
          path,
          File(file.path),
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: mimeType,
          ),
        );
      }
      debugPrint('Media upload successful for path: $path');
    } catch (e, stack) {
      debugPrint('Error uploading media: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  Future<String> getMediaUrl(String path) async {
    try {
      debugPrint('Generating public URL for path: $path');
      final url = _supabase.storage
          .from(_eventImagesBucket)
          .getPublicUrl(path);
      debugPrint('Generated public URL: $url');
      return url;
    } catch (e, stack) {
      debugPrint('Error generating public URL: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  Future<void> deleteEventMedia(String path) async {
    try {
      await _supabase.storage.from(_eventImagesBucket).remove([path]);
    } catch (e) {
      debugPrint('Error deleting media: $e');
      rethrow;
    }
  }

  Future<void> deleteEventMediaForEvent(String eventId) async {
    try {
      debugPrint('Deleting media for event: $eventId');
      final List<FileObject> files = await _supabase.storage
          .from(_eventImagesBucket)
          .list(path: eventId);
      
      for (final file in files) {
        await _supabase.storage
            .from(_eventImagesBucket)
            .remove(['$eventId/${file.name}']);
      }
      debugPrint('Media deletion complete');
    } catch (e, stack) {
      debugPrint('Error deleting media: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  // Get user's events (as creator or participant)
  Future<List<Event>> getUserEvents(String userId) async {
    // Get events created by user
    final createdEvents = await _supabase
        .from(_eventsTable)
        .select()
        .eq('creator_id', userId);

    // Get events where user is a participant
    final participatedEventIds = await _supabase
        .from(_participantsTable)
        .select('event_id')
        .eq('user_id', userId)
        .eq('status', ParticipantStatus.accepted.name);

    // Extract event IDs from the response
    final eventIds = participatedEventIds.map((e) => e['event_id'].toString()).toList();

    // Get participated events if there are any
    List participatedEvents = [];
    if (eventIds.isNotEmpty) {
      participatedEvents = await _supabase
          .from(_eventsTable)
          .select()
          .filter('id', 'in', '(${eventIds.join(',')})');
    }

    // Combine and convert all events
    final allEvents = [...createdEvents, ...participatedEvents];
    return allEvents.map((data) => Event.fromMap(data)).toList();
  }

  // Get saved events for a user
  Future<List<Event>> getSavedEvents(String userId) async {
    try {
      final response = await _supabase
          .from(_savedEventsTable)
          .select('*, events!inner(*)')
          .eq('user_id', userId)
          .filter('events.deleted_at', 'is', 'null'); // Only show non-deleted events
      
      return response
          .map((data) => Event.fromMap(data['events'] as Map<String, dynamic>))
          .where((event) => event != null)
          .toList()
          .cast<Event>();
    } catch (e) {
      debugPrint('Error getting saved events: $e');
      return [];
    }
  }

  // Save an event for a user
  Future<void> saveEvent(String userId, String eventId) async {
    try {
      await _supabase.from(_savedEventsTable).insert({
        'user_id': userId,
        'event_id': eventId,
      });
    } catch (e) {
      debugPrint('Error saving event: $e');
      rethrow;
    }
  }

  // Unsave an event for a user
  Future<void> unsaveEvent(String userId, String eventId) async {
    try {
      await _supabase
          .from(_savedEventsTable)
          .delete()
          .eq('user_id', userId)
          .eq('event_id', eventId);
    } catch (e) {
      debugPrint('Error unsaving event: $e');
      rethrow;
    }
  }

  // Check if an event is saved by a user
  Future<bool> isEventSaved(String userId, String eventId) async {
    try {
      final response = await _supabase
          .from(_savedEventsTable)
          .select()
          .eq('user_id', userId)
          .eq('event_id', eventId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      debugPrint('Error checking if event is saved: $e');
      return false;
    }
  }

  // Get events created by a user
  Future<List<Event>> getCreatedEvents(String userId) async {
    final response = await _supabase
        .from(_eventsTable)
        .select()
        .eq('creator_id', userId)
        .filter('deleted_at', 'is', 'null'); // Only show non-deleted events
    
    return response.map((data) => Event.fromMap(data)).toList();
  }

  // Get events joined by a user
  Future<List<Event>> getJoinedEvents(String userId) async {
    try {
      final response = await _supabase
          .from(_participantsTable)
          .select('event_id, events!inner(*), status')
          .eq('user_id', userId)
          .eq('status', ParticipantStatus.accepted.name)
          .not('events.creator_id', 'eq', userId) // Exclude events where user is creator
          .filter('events.deleted_at', 'is', 'null'); // Only show non-deleted events
      
      return response
          .map((data) => Event.fromMap(data['events']))
          .where((event) => event != null)
          .toList()
          .cast<Event>();
    } catch (e) {
      debugPrint('Error getting joined events: $e');
      return [];
    }
  }

  // Get favorite events for a user
  Future<List<Event>> getFavoriteEvents(String userId) async {
    try {
      final response = await _supabase
          .from(_favoriteEventsTable)
          .select('event_id, events!inner(*)')
          .eq('user_id', userId)
          .filter('events.deleted_at', 'is', 'null'); // Only show non-deleted events
      
      return response
          .map((data) => Event.fromMap(data['events']))
          .where((event) => event != null)
          .toList()
          .cast<Event>();
    } catch (e) {
      debugPrint('Error getting favorite events: $e');
      return [];
    }
  }

  // Favorite an event for a user
  Future<void> favoriteEvent(String userId, String eventId) async {
    try {
      // Clean the event ID by removing ALL whitespace
      final cleanEventId = eventId.replaceAll(RegExp(r'\s+'), '');
      debugPrint('Processing favorite request for event ID: $cleanEventId (original: $eventId)');
      
      // Check if already favorited with either ID
      final existing = await isEventFavorited(userId, cleanEventId) || 
                      (cleanEventId != eventId && await isEventFavorited(userId, eventId));
      
      if (existing) {
        debugPrint('Event already favorited');
        return;
      }
      
      // Debug: Get event details
      var event = await getEventById(cleanEventId);
      
      // If not found with cleaned ID, try original
      if (event == null && cleanEventId != eventId) {
        event = await getEventById(eventId);
      }
      
      if (event == null) {
        debugPrint('Event lookup failed for both cleaned and original IDs');
        throw Exception('Event not found: $eventId (cleaned: $cleanEventId)');
      }
      
      debugPrint('Found event: ${event.toMap()}');
      debugPrint('Current user ID: $userId');
      debugPrint('Event visibility: ${event.visibility}');
      debugPrint('Event creator: ${event.creatorId}');
      
      // Check if user is participant for private events
      if (event.visibility == EventVisibility.private) {
        final isParticipant = await _supabase
            .from(_participantsTable)
            .select()
            .eq('event_id', event.id)
            .eq('user_id', userId)
            .eq('status', 'accepted')
            .maybeSingle();
            
        debugPrint('Is user participant? ${isParticipant != null}');
        
        if (isParticipant == null && event.creatorId != userId) {
          throw Exception('Cannot favorite private event: User is not a participant or creator');
        }
      }
      
      // Try to insert with unique constraint
      try {
        await _supabase.from(_favoriteEventsTable).upsert(
          {
            'user_id': userId,
            'event_id': event.id,
          },
          onConflict: 'user_id,event_id'
        );
        debugPrint('Successfully favorited event ${event.id}');
      } catch (e) {
        if (e is PostgrestException && e.code == '23505') { // Unique violation code
          debugPrint('Event already favorited (caught unique constraint)');
          return;
        }
        rethrow;
      }
    } catch (e, stack) {
      debugPrint('Error favoriting event: $e');
      debugPrint('Stack trace: $stack'); 
      rethrow;
    }
  }

  // Unfavorite an event for a user
  Future<void> unfavoriteEvent(String userId, String eventId) async {
    await _supabase
        .from(_favoriteEventsTable)
        .delete()
        .eq('user_id', userId)
        .eq('event_id', eventId);
  }

  // Check if an event is favorited by a user
  Future<bool> isEventFavorited(String userId, String eventId) async {
    try {
      // Clean the event ID by removing ALL whitespace
      final cleanEventId = eventId.replaceAll(RegExp(r'\s+'), '');
      debugPrint('Checking if event is favorited - cleaned ID: $cleanEventId (original: $eventId)');
    
      // Try with cleaned ID first
      var response = await _supabase
          .from(_favoriteEventsTable)
          .select()
          .eq('user_id', userId)
          .eq('event_id', cleanEventId)
          .maybeSingle();
          
      // If not found and IDs are different, try original
      if (response == null && cleanEventId != eventId) {
        response = await _supabase
            .from(_favoriteEventsTable)
            .select()
            .eq('user_id', userId)
            .eq('event_id', eventId)
            .maybeSingle();
      }
    
      debugPrint('Favorited check result: ${response != null}');
      return response != null;
    } catch (e, stack) {
      debugPrint('Error checking if event is favorited: $e');
      debugPrint('Stack trace: $stack');
      return false;
    }
  }

  // Join private event with access code
  Future<bool> joinPrivateEvent(String eventId, String accessCode) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Call the verify_and_join_private_event function
      final response = await _supabase
          .rpc('verify_and_join_private_event', params: {
        'p_event_id': eventId,
        'p_user_id': userId,
        'p_access_code': accessCode,
      });

      return response as bool;
    } catch (e, stack) {
      debugPrint('Error joining private event: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  // Update event access code (for event creators)
  Future<void> updateEventAccessCode(String eventId, String accessCode) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Verify user is event creator
      final event = await getEventById(eventId);
      if (event == null || event.creatorId != userId) {
        throw Exception('Not authorized to update event access code');
      }

      await _supabase
          .from(_eventsTable)
          .update({'access_code': accessCode})
          .eq('id', eventId);
    } catch (e, stack) {
      debugPrint('Error updating event access code: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }
}
