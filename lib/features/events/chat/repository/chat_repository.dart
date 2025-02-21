import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import '../models/chat_room.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/chat_media.dart';

final chatRepositoryProvider = Provider((ref) => ChatRepository());

class ChatRepository {
  final _supabase = Supabase.instance.client;
  
  String? get currentUserId => _supabase.auth.currentUser?.id;
  
  // Chat Room Operations
  Future<ChatRoom?> getChatRoom(String eventId) async {
    try {
      // First check if the user has access to the event
      final userId = _supabase.auth.currentUser?.id;
      debugPrint('Getting chat room for event $eventId, user $userId');
      
      if (userId == null) {
        debugPrint('User not authenticated');
        throw Exception('User not authenticated');
      }

      final hasAccess = await _checkEventAccess(eventId, userId);
      debugPrint('User has access to event: $hasAccess');
      
      if (!hasAccess) {
        debugPrint('User does not have access to this event');
        return null;
      }

      final response = await _supabase
          .from('event_chat_rooms')
          .select()
          .eq('event_id', eventId)
          .eq('room_type', 'general')
          .maybeSingle();
      
      debugPrint('Chat room query response: $response');
      
      if (response == null) {
        debugPrint('No chat room found for event');
        return null;
      }
      
      return ChatRoom.fromMap(response);
    } catch (e, stackTrace) {
      debugPrint('Error getting chat room: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<ChatRoom> createChatRoom(String eventId) async {
    try {
      debugPrint('Creating new chat room for event $eventId');
      final now = DateTime.now().toUtc();
      final response = await _supabase
          .from('event_chat_rooms')
          .insert({
            'event_id': eventId,
            'name': 'General',
            'room_type': 'general',
            'description': 'General chat room for event',
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
            'is_active': true
          })
          .select()
          .single();
      
      debugPrint('Chat room created successfully: $response');
      return ChatRoom.fromMap(response);
    } catch (e, stackTrace) {
      debugPrint('Error creating chat room: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Stream<ChatRoom?> watchChatRoom(String eventId) {
    try {
      return _supabase
          .from('event_chat_rooms')
          .stream(primaryKey: ['id'])
          .map((events) {
            if (events.isEmpty) return null;
            // Filter events in-memory since we can't chain .eq() on stream
            final filtered = events.where((room) =>
              room['event_id'] == eventId &&
              room['room_type'] == 'general'
            );
            if (filtered.isEmpty) return null;
            return ChatRoom.fromMap(filtered.first);
          });
    } catch (e) {
      debugPrint('Error watching chat room: $e');
      return Stream.value(null);
    }
  }

  Future<bool> _checkEventAccess(String eventId, String userId) async {
    try {
      // Check if user is event creator
      final isCreator = await _isEventCreator(eventId, userId);
      if (isCreator) return true;

      // Check if user is an accepted participant
      final participant = await _supabase
          .from('event_participants')
          .select()
          .eq('event_id', eventId)
          .eq('user_id', userId)
          .eq('status', 'accepted')
          .maybeSingle();
      
      return participant != null;
    } catch (e) {
      debugPrint('Error checking event access: $e');
      return false;
    }
  }

  Future<bool> _isEventCreator(String eventId, String userId) async {
    try {
      final event = await _supabase
          .from('events')
          .select('creator_id')
          .eq('id', eventId)
          .single();
      
      return event['creator_id'] == userId;
    } catch (e) {
      debugPrint('Error checking if user is event creator: $e');
      return false;
    }
  }

  // Chat Messages Operations
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String content,
    required MessageType type,
    ChatMedia? media,
  }) async {
    try {
      // Create the message
      final messageData = await _supabase
          .from('event_chat_messages')
          .insert({
            'chat_room_id': roomId,
            'sender_id': _supabase.auth.currentUser!.id,
            'content': content,
            'message_type': type.toString().split('.').last,
            if (media != null) ...{
              'media_url': media.url,
              'media_type': media.type.toString().split('.').last,
            },
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('*, sender:sender_id(id, username, full_name, avatar_url)')
          .single();

      // Get sender profile
      final senderProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', _supabase.auth.currentUser!.id)
          .single();

      return ChatMessage.fromMap({
        ...messageData,
        'sender_profile': senderProfile,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> updateMessage({
    required String messageId,
    required String content,
    ChatMedia? media,
  }) async {
    await _supabase
        .from('event_chat_messages')
        .update({
          'content': content,
          if (media != null) ...{
            'media_url': media.url,
            'media_type': media.type.toString().split('.').last,
            'message_type': 'image',
            'type': 'image',
            'thumbnail_url': media.url,
            'file_name': media.fileName,
            'mime_type': media.mimeType,
          },
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId)
        .eq('sender_id', _supabase.auth.currentUser!.id);
  }

  Stream<List<ChatMessage>> getChatMessages(String roomId) {
    return _supabase
        .from('event_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_room_id', roomId)
        .order('created_at', ascending: false)
        .asyncMap((events) async {
          debugPrint('Fetched ${events.length} messages');
          final messages = <ChatMessage>[];
          
          for (final event in events) {
            try {
              final senderProfile = await _supabase
                  .from('profiles')
                  .select()
                  .eq('id', event['sender_id'])
                  .single();
              
              messages.add(ChatMessage.fromMap({
                ...event,
                'sender_profile': senderProfile,
              }));
            } catch (e) {
              debugPrint('Error fetching profile for message ${event['id']}: $e');
              // Add message without profile if profile fetch fails
              messages.add(ChatMessage.fromMap(event));
            }
          }
          
          return messages;
        });
  }

  // Chat Participants Operations
  Future<void> addParticipant({
    required String roomId,
    required String userId,
    required ParticipantRole role,
  }) async {
    await _supabase.from('event_chat_participants').insert({
      'room_id': roomId,
      'user_id': userId,
      'role': role.toString().split('.').last,
    });
  }

  Future<List<ChatParticipant>> getChatParticipants(String roomId) async {
    final response = await _supabase
        .from('event_chat_participants')
        .select()
        .eq('room_id', roomId);
    return response.map<ChatParticipant>((json) => ChatParticipant.fromMap(json)).toList();
  }

  Future<void> updateLastRead(String roomId) async {
    await _supabase
        .from('event_chat_participants')
        .update({'last_read_at': DateTime.now().toIso8601String()})
        .eq('room_id', roomId)
        .eq('user_id', _supabase.auth.currentUser!.id);
  }

  // Media Operations
  String _getMimeType(Uint8List bytes, String fileName) {
    // First try to detect from bytes
    if (bytes.length >= 2) {
      // Check for JPEG
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        return 'image/jpeg';
      }
      // Check for PNG
      if (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
    }
    
    // Then try from file extension
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.heic':
        return 'image/heic';
    }
    
    // Finally try mime package
    return lookupMimeType(fileName) ?? 'image/jpeg'; // Default to JPEG instead of octet-stream
  }

  String _getFileExtension(String mimeType, String originalPath) {
    // First try to get from original path
    final originalExt = path.extension(originalPath).toLowerCase();
    if (originalExt.isNotEmpty) {
      return originalExt;
    }
    
    // If no extension, derive from MIME type
    switch (mimeType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      case 'image/heic':
        return '.heic';
      default:
        return '.jpg'; // Default to jpg for images
    }
  }

  Future<ChatMedia> uploadMedia({
    required String messageId,
    required String filePath,
    required Uint8List bytes,
  }) async {
    try {
      final fileName = path.basename(filePath);
      final mimeType = _getMimeType(bytes, fileName);
      final fileExt = _getFileExtension(mimeType, filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '$messageId-$timestamp$fileExt';

      // First verify the message exists and user has access
      final messages = await _supabase
          .from('event_chat_messages')
          .select('id, chat_room_id, sender_id')
          .eq('id', messageId)
          .eq('sender_id', _supabase.auth.currentUser!.id)
          .limit(1);

      if (messages.isEmpty) {
        throw Exception('Message not found or unauthorized');
      }
      final message = messages[0];

      // Upload the file to storage with explicit content type
      final String storagePath = uniqueFileName;
      final uploadResponse = await _supabase
          .storage
          .from('event_chat_media')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      if (uploadResponse == null) {
        throw Exception('Failed to upload media');
      }

      // Get the public URL
      final url = _supabase.storage
          .from('event_chat_media')
          .getPublicUrl(storagePath);

      // Update the message with media information
      final messageResponses = await _supabase
          .from('event_chat_messages')
          .update({
            'media_url': url,
            'media_type': 'image',  // Since we're handling images
            'message_type': 'image',
            'type': 'image',
            'thumbnail_url': url,  // For images, use same URL
            'file_name': fileName,
            'mime_type': mimeType,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .eq('sender_id', _supabase.auth.currentUser!.id)
          .select('*, sender:profiles!event_chat_messages_sender_id_fkey(id, username, full_name, avatar_url)');

      if (messageResponses.isEmpty) {
        throw Exception('Failed to update message with media');
      }

      debugPrint('Successfully uploaded image: $url');
      debugPrint('MIME Type: $mimeType');
      debugPrint('File Extension: $fileExt');

      // Insert media metadata
      final mediaResponses = await _supabase
          .from('event_chat_media')
          .insert({
            'message_id': messageId,
            'url': url,
            'type': 'image',
            'thumbnail_url': url, // For images, use the same URL
            'file_name': '$fileName$fileExt', // Ensure filename has extension
            'file_size': bytes.length,
            'mime_type': mimeType,
            'owner_id': _supabase.auth.currentUser!.id,
          })
          .select();

      if (mediaResponses.isEmpty) {
        throw Exception('Failed to create media record');
      }
      final mediaResponse = mediaResponses[0];

      return ChatMedia.fromMap(mediaResponse);
    } catch (e) {
      debugPrint('Error in uploadMedia: $e');
      rethrow;
    }
  }

  // Helper method to convert URL to Uint8List
  Future<Uint8List> urlToBytes(String url) async {
    final response = await http.get(Uri.parse(url));
    return response.bodyBytes;
  }
}
