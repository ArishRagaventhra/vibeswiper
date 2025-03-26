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

      // Use orderBy to get the oldest chat room first and limit to 1 to avoid multiple rows
      final response = await _supabase
          .from('event_chat_rooms')
          .select()
          .eq('event_id', eventId)
          .eq('room_type', 'general')
          .order('created_at', ascending: true)
          .limit(1)
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
            ).toList();
            if (filtered.isEmpty) return null;
            
            // Take only the first room if multiple exist
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
      // Map MessageType to database message_type
      String dbMessageType;
      String dbType;
      
      switch (type) {
        case MessageType.file:
          dbMessageType = 'text';  // For files, we use 'text' as message_type
          dbType = 'file';        // and 'file' as type
          break;
        case MessageType.text:
          dbMessageType = 'text';
          dbType = 'text';
          break;
        case MessageType.image:
          dbMessageType = 'image';
          dbType = 'image';
          break;
        case MessageType.video:
          dbMessageType = 'video';
          dbType = 'text';  // Since video isn't allowed in type constraint
          break;
      }

      // Create the message
      final messageDataResponse = await _supabase
          .from('event_chat_messages')
          .insert({
            'chat_room_id': roomId,
            'sender_id': _supabase.auth.currentUser!.id,
            'content': content,
            'message_type': dbMessageType,
            'type': dbType,
            if (media != null) ...{
              'media_url': media.url,
              'media_type': type.toString().split('.').last.toLowerCase(),
              'thumbnail_url': media.thumbnailUrl,
              'file_name': media.fileName,
              'mime_type': media.mimeType,
              'file_size': media.fileSize,  // Add file size to the message
            },
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select();
      
      if (messageDataResponse.isEmpty) {
        throw Exception('Failed to create message');
      }
      
      final messageData = messageDataResponse.first;

      // Get sender profile in a separate query
      final senderProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', _supabase.auth.currentUser!.id)
          .maybeSingle();
      
      if (senderProfile == null) {
        throw Exception('Failed to get sender profile');
      }

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
    String? dbMessageType;
    String? dbType;

    if (media != null) {
      switch (media.type) {
        case MediaType.file:
          dbMessageType = 'text';
          dbType = 'file';
          break;
        case MediaType.image:
          dbMessageType = 'image';
          dbType = 'image';
          break;
        case MediaType.video:
          dbMessageType = 'video';
          dbType = 'text';
          break;
      }
    }

    await _supabase
        .from('event_chat_messages')
        .update({
          'content': content,
          if (media != null) ...{
            'media_url': media.url,
            'media_type': media.type.toString().split('.').last.toLowerCase(),
            'message_type': dbMessageType,
            'type': dbType,
            'thumbnail_url': media.thumbnailUrl,
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
    final ext = path.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.doc':
      case '.docx':
        return 'application/msword';
      case '.xls':
      case '.xlsx':
        return 'application/vnd.ms-excel';
      case '.txt':
        return 'text/plain';
      default:
        // Try to detect image mime type
        final mimeType = lookupMimeType(fileName, headerBytes: bytes);
        return mimeType ?? 'application/octet-stream';
    }
  }

  String _getFileExtension(String mimeType, String filePath) {
    final originalExt = path.extension(filePath);
    if (originalExt.isNotEmpty) return originalExt;

    switch (mimeType) {
      case 'application/pdf':
        return '.pdf';
      case 'application/msword':
        return '.doc';
      case 'application/vnd.ms-excel':
        return '.xls';
      case 'text/plain':
        return '.txt';
      default:
        return '';
    }
  }

  Future<ChatMedia> uploadMedia({
    required String messageId,
    required String filePath,
    required Uint8List bytes,
    MessageType type = MessageType.file,
  }) async {
    try {
      final fileName = path.basename(filePath);
      final mimeType = _getMimeType(bytes, fileName);
      final fileExt = _getFileExtension(mimeType, filePath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '$messageId-$timestamp$fileExt';

      // First verify the message exists and user has access
      final message = await _supabase
          .from('event_chat_messages')
          .select()
          .eq('id', messageId)
          .eq('sender_id', _supabase.auth.currentUser!.id)
          .single();

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

      // Map message type to database constraints
      String dbMessageType;
      String dbType;
      switch (type) {
        case MessageType.file:
          dbMessageType = 'text';  // Use 'text' for files as per constraint
          dbType = 'file';
          break;
        case MessageType.text:
          dbMessageType = 'text';
          dbType = 'text';
          break;
        case MessageType.image:
          dbMessageType = 'image';
          dbType = 'image';
          break;
        case MessageType.video:
          dbMessageType = 'video';
          dbType = 'text';  // Use 'text' for video as per constraint
          break;
      }

      // First insert media metadata
      final mediaData = {
        'message_id': messageId,
        'url': url,
        'type': type.toString().split('.').last.toLowerCase(),
        'thumbnail_url': type == MessageType.image ? url : null,
        'file_name': fileName,
        'file_size': bytes.length,
        'mime_type': mimeType,
        'owner_id': _supabase.auth.currentUser!.id,
      };

      final mediaResponse = await _supabase
          .from('event_chat_media')
          .insert(mediaData)
          .select()
          .single();

      // Then update the message with media information
      await _supabase
          .from('event_chat_messages')
          .update({
            'media_url': url,
            'media_type': type.toString().split('.').last.toLowerCase(),
            'message_type': dbMessageType,
            'type': dbType,
            'thumbnail_url': type == MessageType.image ? url : null,
            'file_name': fileName,
            'mime_type': mimeType,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', messageId)
          .eq('sender_id', _supabase.auth.currentUser!.id);

      debugPrint('Successfully uploaded file: $url');
      debugPrint('MIME Type: $mimeType');
      debugPrint('File Extension: $fileExt');
      debugPrint('File Size: ${bytes.length} bytes');

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
