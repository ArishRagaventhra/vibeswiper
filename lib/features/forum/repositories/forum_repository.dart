import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/forum_constants.dart';
import '../models/forum.dart';
import '../models/forum_member.dart';
import '../models/forum_message.dart';
import '../models/forum_message_media.dart';
import '../models/forum_report.dart';

class ForumRepository {
  final SupabaseClient _supabase;

  ForumRepository(this._supabase);

  // Forum Operations
  Future<List<Forum>> getPublicForums() async {
    final response = await _supabase
        .from(ForumConstants.tableForum)
        .select()
        .eq('is_private', false)
        .filter('deleted_at', 'is', null)  // Only get non-deleted forums
        .order('created_at', ascending: false);
    
    return response.map((json) => Forum.fromJson(json)).toList();
  }

  Future<List<Forum>> getUserForums() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from(ForumConstants.tableForumMembers)
        .select('forum:forums(*)')
        .eq('user_id', userId)
        .filter('forum.deleted_at', 'is', null);  // Only get non-deleted forums

    return response
        .map((json) => Forum.fromJson(json['forum']))
        .toList();
  }

  Future<Forum> createForum(Forum forum) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Convert forum to map and remove the id field
    final forumData = forum.toJson();
    forumData.remove('id');  // Remove ID to let Supabase generate it
    forumData['created_by'] = userId;  // Set creator ID

    // Create the forum
    final response = await _supabase
        .from(ForumConstants.tableForum)
        .insert(forumData)
        .select()
        .single();
    
    final createdForum = Forum.fromJson(response);

    // Add creator as first member with admin role
    await _supabase.from(ForumConstants.tableForumMembers).insert({
      'forum_id': createdForum.id,
      'user_id': userId,
      'role': ForumConstants.roleAdmin,
      'joined_at': DateTime.now().toIso8601String(),
      'last_read_at': DateTime.now().toIso8601String(),
    });
    
    return createdForum;
  }

  Future<void> updateForum(Forum forum) async {
    await _supabase
        .from(ForumConstants.tableForum)
        .update(forum.toJson())
        .eq('id', forum.id);
  }

  Future<void> deleteForum(String forumId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw 'User not authenticated';

    // Check if user is the creator
    final forum = await getForumById(forumId);
    if (forum == null) throw 'Forum not found';
    if (forum.createdBy != userId) throw 'Only forum creators can delete forums';

    // Soft delete the forum by setting deleted_at
    await _supabase
        .from(ForumConstants.tableForum)
        .update({ 'deleted_at': DateTime.now().toIso8601String() })
        .eq('id', forumId);
  }

  // Get all forums for discover tab
  Future<List<Forum>> getAllForums() async {
    try {
      final response = await _supabase
          .from(ForumConstants.tableForum)
          .select()
          .filter('deleted_at', 'is', null)  // Only get non-deleted forums
          .order('created_at', ascending: false);
      
      return response.map((json) => Forum.fromJson(json)).toList();
    } catch (e) {
      throw 'Failed to get forums: $e';
    }
  }

  Future<List<Forum>> getCreatedForums() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final response = await _supabase
          .from(ForumConstants.tableForum)
          .select()
          .eq('created_by', userId)
          .filter('deleted_at', 'is', null)
          .order('created_at', ascending: false);

      return response.map((json) => Forum.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching created forums: $e');
      return [];
    }
  }

  Future<List<Forum>> getJoinedForums() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    try {
      final response = await _supabase
          .from(ForumConstants.tableForumMembers)
          .select('''
            forum:forums (
              id,
              name,
              description,
              profile_image_url,
              banner_image_url,
              is_private,
              access_code,
              member_count,
              message_count,
              created_at,
              updated_at,
              created_by,
              settings
            )
          ''')
          .eq('user_id', userId)
          .filter('forum.deleted_at', 'is', null)
          .filter('forum.created_by', 'neq', userId);  // Exclude forums created by the user

      return response
          .where((json) => json['forum'] != null)
          .map((json) => Forum.fromJson(json['forum'] as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching joined forums: $e');
      return [];  // Return empty list on error
    }
  }

  Future<Forum?> getForumById(String forumId) async {
    final response = await _supabase
        .from(ForumConstants.tableForum)
        .select()
        .eq('id', forumId)
        .filter('deleted_at', 'is', null)  // Only get non-deleted forums
        .maybeSingle();

    return response == null ? null : Forum.fromJson(response);
  }

  // Forum Member Operations
  Future<List<ForumMember>> getForumMembers(String forumId) async {
    final response = await _supabase
        .from(ForumConstants.tableForumMembers)
        .select()
        .eq('forum_id', forumId);
    
    return response.map((json) => ForumMember.fromJson(json)).toList();
  }

  Future<void> joinForum(String forumId, {String? accessCode}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Start a transaction
    await _supabase.rpc('join_forum', params: {
      'forum_id_param': forumId,
      'user_id_param': userId,
      'access_code_param': accessCode,
      'role_param': ForumConstants.roleMember,
    });
  }

  Future<void> leaveForum(String forumId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from(ForumConstants.tableForumMembers)
        .delete()
        .eq('forum_id', forumId)
        .eq('user_id', userId);
  }

  // Message Operations
  Future<List<ForumMessage>> getForumMessages(
    String forumId, {
    int limit = 50,
    DateTime? before,
  }) async {
    var query = _supabase
        .from(ForumConstants.tableForumMessages)
        .select()
        .eq('forum_id', forumId);

    if (before != null) {
      query = query.lte('created_at', before.toIso8601String());
    }

    final messages = await query
        .order('created_at', ascending: false)
        .limit(limit);

    // Fetch media separately for each message
    final List<ForumMessage> messageList = [];
    for (final msgJson in messages) {
      final media = await _supabase
          .from(ForumConstants.tableForumMessageMedia)
          .select()
          .eq('message_id', msgJson['id'])
          .maybeSingle();
      
      messageList.add(ForumMessage.fromJson({
        ...msgJson,
        'media': media,
      }));
    }

    return messageList;
  }

  Future<ForumMessage> sendMessage(ForumMessage message) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Convert message to map and set the sender ID
    final messageData = message.toJson();
    messageData['sender_id'] = userId;
    
    // Remove media from message data as it's stored separately
    messageData.remove('media');

    final response = await _supabase
        .from(ForumConstants.tableForumMessages)
        .insert(messageData)
        .select()
        .single();
    
    return ForumMessage.fromJson(response);
  }

  Future<void> deleteMessage(String messageId) async {
    await _supabase
        .from(ForumConstants.tableForumMessages)
        .update({'deleted_at': DateTime.now().toIso8601String()})
        .eq('id', messageId);
  }

  Future<void> pinMessage(String messageId, bool isPinned) async {
    await _supabase
        .from(ForumConstants.tableForumMessages)
        .update({'is_pinned': isPinned})
        .eq('id', messageId);
  }

  // Media Operations
  Future<ForumMessageMedia> uploadMedia(
    ForumMessageMedia media,
    Uint8List fileBytes,
  ) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // First, ensure the message exists and user has permission
    final message = await _supabase
        .from(ForumConstants.tableForumMessages)
        .select('forum_id, id, sender_id')
        .eq('id', media.messageId)
        .single();

    if (message == null) {
      throw Exception('Message not found');
    }

    // Ensure the user is the message sender
    if (message['sender_id'] != userId) {
      throw Exception('Only the message sender can add media');
    }

    final forumId = message['forum_id'] as String;
    
    // Check if user is a member of the forum
    final memberCheck = await _supabase
        .from(ForumConstants.tableForumMembers)
        .select()
        .eq('forum_id', forumId)
        .eq('user_id', userId)
        .maybeSingle();

    if (memberCheck == null) {
      throw Exception('User is not a member of this forum');
    }

    // Upload the file
    final filePath = '${media.messageId}/${media.fileName}';
    final storageResponse = await _supabase
        .storage
        .from(ForumConstants.forumMediaBucket)
        .uploadBinary(
          filePath,
          fileBytes,
          fileOptions: FileOptions(
            contentType: media.mimeType,
            upsert: true,
          ),
        );

    if (storageResponse.isEmpty) {
      throw Exception('Failed to upload file to storage');
    }

    // Get the public URL for the uploaded file
    final mediaUrl = _supabase
        .storage
        .from(ForumConstants.forumMediaBucket)
        .getPublicUrl(filePath);

    final mediaWithUrl = ForumMessageMedia(
      id: media.id,
      messageId: media.messageId,
      url: mediaUrl,
      type: media.type,
      thumbnailUrl: media.thumbnailUrl,
      fileName: media.fileName,
      fileSize: media.fileSize,
      mimeType: media.mimeType,
      createdAt: media.createdAt,
      metadata: {
        ...media.metadata,
        'uploadedBy': userId,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );

    try {
      // First update the message type and metadata
      await _supabase
          .from(ForumConstants.tableForumMessages)
          .update({
            'message_type': media.type,
            'metadata': {
              ...message['metadata'] as Map<String, dynamic>? ?? {},
              'hasMedia': true,
              'mediaType': media.type,
            },
          })
          .eq('id', media.messageId);

      // Then create the media record
      final response = await _supabase
          .from(ForumConstants.tableForumMessageMedia)
          .insert(mediaWithUrl.toJson())
          .select('*, message:forum_messages(*)')
          .single();

      // Return the created media
      return ForumMessageMedia.fromJson(response);
    } catch (e) {
      // If database insert fails, try to clean up the uploaded file
      try {
        await _supabase
            .storage
            .from(ForumConstants.forumMediaBucket)
            .remove([filePath]);
      } catch (_) {
        // Ignore cleanup errors
      }
      rethrow;
    }
  }

  Future<ForumMessage?> getMessageWithMedia(String messageId) async {
    final response = await _supabase
        .from(ForumConstants.tableForumMessages)
        .select('*, media:forum_message_media(*)')
        .eq('id', messageId)
        .single();
    
    return ForumMessage.fromJson(response);
  }

  Future<String> uploadForumImage(String forumId, Uint8List imageBytes, String imagePath) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    // Ensure the user has permission (either creator or admin)
    final forum = await _supabase
        .from(ForumConstants.tableForum)
        .select('created_by')
        .eq('id', forumId)
        .single();
    
    if (forum == null) {
      throw Exception('Forum not found');
    }

    final isCreator = forum['created_by'] == userId;
    if (!isCreator) {
      final member = await _supabase
          .from(ForumConstants.tableForumMembers)
          .select('role')
          .eq('forum_id', forumId)
          .eq('user_id', userId)
          .single();
      
      if (member == null || member['role'] != ForumConstants.roleAdmin) {
        throw Exception('Only forum creators and admins can update forum images');
      }
    }

    // Create a unique file path with timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$forumId/$imagePath/$timestamp.jpg';

    // First, try to delete any existing images in this path
    try {
      final List<FileObject> existingFiles = await _supabase.storage
          .from(ForumConstants.forumImagesBucket)
          .list(path: '$forumId/$imagePath');

      if (existingFiles.isNotEmpty) {
        await _supabase.storage
            .from(ForumConstants.forumImagesBucket)
            .remove(existingFiles.map((f) => '$forumId/$imagePath/${f.name}').toList());
      }
    } catch (e) {
      // Ignore errors when trying to delete old files
    }

    // Upload the new image
    final response = await _supabase.storage
        .from(ForumConstants.forumImagesBucket)
        .uploadBinary(
          filePath,
          imageBytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            cacheControl: '3600',
            upsert: true,
          ),
        );

    if (response.isEmpty) {
      throw Exception('Failed to upload image');
    }

    // Get the public URL with cache busting parameter
    final imageUrl = '${_supabase.storage
        .from(ForumConstants.forumImagesBucket)
        .getPublicUrl(filePath)}?v=$timestamp';

    return imageUrl;
  }

  Future<void> deleteForumImage(String forumId, String path) async {
    // Determine the image type (profile or banner)
    final imagePath = path == 'profile' ? ForumConstants.forumProfileImagePath : ForumConstants.forumBannerImagePath;
    final filePath = '$forumId/$imagePath.jpg';

    try {
      await _supabase.storage
          .from(ForumConstants.forumImagesBucket)
          .remove([filePath]);
    } catch (e) {
      // Ignore if file doesn't exist
    }
  }

  // Report Operations
  Future<void> createReport(ForumReport report) async {
    await _supabase
        .from(ForumConstants.tableForumReports)
        .insert(report.toJson());
  }

  Future<List<ForumReport>> getForumReports(String forumId) async {
    final response = await _supabase
        .from(ForumConstants.tableForumReports)
        .select()
        .eq('forum_id', forumId)
        .order('created_at', ascending: false);
    
    return response.map((json) => ForumReport.fromJson(json)).toList();
  }

  Future<void> updateReportStatus(
    String reportId,
    String status, {
    String? notes,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase.from(ForumConstants.tableForumReports).update({
      'status': status,
      'resolved_by': userId,
      'resolved_at': DateTime.now().toIso8601String(),
      if (notes != null) 'notes': notes,
    }).eq('id', reportId);
  }

  Future<bool> isForumMember(String forumId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _supabase
        .from(ForumConstants.tableForumMembers)
        .select()
        .eq('forum_id', forumId)
        .eq('user_id', userId)
        .maybeSingle();
    
    return response != null;
  }
}
