import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_participant.dart';
import '../models/chat_media.dart';
import '../repository/chat_repository.dart';

final chatControllerProvider = StateNotifierProvider<ChatController, AsyncValue<void>>((ref) {
  return ChatController(ref.watch(chatRepositoryProvider));
});

final chatMessagesProvider = StateNotifierProvider.family<ChatMessagesNotifier, AsyncValue<List<ChatMessage>>, String>((ref, roomId) {
  return ChatMessagesNotifier(ref.watch(chatRepositoryProvider), roomId);
});

final chatRoomProvider = StreamProvider.family<ChatRoom?, String>((ref, eventId) {
  return ref.watch(chatRepositoryProvider).watchChatRoom(eventId);
});

final chatParticipantsProvider = FutureProvider.family<List<ChatParticipant>, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).getChatParticipants(roomId);
});

class ChatMessagesNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final ChatRepository _repository;
  final String roomId;
  StreamSubscription<List<ChatMessage>>? _subscription;

  ChatMessagesNotifier(this._repository, this.roomId) : super(const AsyncValue.loading()) {
    _initialize();
  }

  void _initialize() {
    _subscription = _repository.getChatMessages(roomId).listen(
      (messages) {
        state = AsyncValue.data(messages);
      },
      onError: (error, stackTrace) {
        if (error is SocketException) {
          debugPrint('Socket error fetching chat messages: $error');
        } else if (error is TimeoutException) {
          debugPrint('Timeout error fetching chat messages: $error');
        } else {
          debugPrint('Error fetching chat messages: $error');
        }
        state = AsyncValue.error(error, stackTrace);
      },
    );
  }

  Future<ChatMessage> sendMessage({
    required String content,
    required MessageType type,
    ChatMedia? media,
  }) async {
    try {
      final message = await _repository.sendMessage(
        roomId: roomId,
        content: content,
        type: type,
        media: media,
      );

      // Update the state with the new message
      if (state is AsyncData<List<ChatMessage>>) {
        final messages = List<ChatMessage>.from((state as AsyncData<List<ChatMessage>>).value);
        messages.insert(0, message); // Add new message to the beginning of the list
        state = AsyncValue.data(messages);
      }
      return message;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> updateMessage(
    String messageId, {
    String? content,
    ChatMedia? media,
  }) async {
    try {
      // Get the current message first
      final currentState = state;
      if (currentState is AsyncData<List<ChatMessage>>) {
        final messages = List<ChatMessage>.from(currentState.value);
        final messageIndex = messages.indexWhere((m) => m.id == messageId);
        
        if (messageIndex != -1) {
          // Update the message in the repository
          await _repository.updateMessage(
            messageId: messageId,
            content: content ?? messages[messageIndex].content,
            media: media,
          );
          
          // Update the message in the local state
          final updatedMessage = messages[messageIndex].copyWith(
            content: content ?? messages[messageIndex].content,
            media: media ?? messages[messageIndex].media,
            updatedAt: DateTime.now(),
          );
          
          messages[messageIndex] = updatedMessage;
          state = AsyncValue.data(messages);
        }
      }
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class ChatController extends StateNotifier<AsyncValue<void>> {
  final ChatRepository _repository;

  ChatController(this._repository) : super(const AsyncValue.data(null));

  Future<ChatRoom?> getChatRoom(String eventId) async {
    return _repository.getChatRoom(eventId);
  }

  Future<void> initializeChatRoom(String eventId) async {
    state = const AsyncValue.loading();
    try {
      var chatRoom = await _repository.getChatRoom(eventId);
      if (chatRoom == null) {
        chatRoom = await _repository.createChatRoom(eventId);
      }
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<ChatMedia> uploadMedia({
    required String messageId,
    required String filePath,
    required Uint8List bytes,
    MessageType type = MessageType.file,
  }) async {
    try {
      return await _repository.uploadMedia(
        messageId: messageId,
        filePath: filePath,
        bytes: bytes,
        type: type,
      );
    } catch (e) {
      debugPrint('Error uploading media: $e');
      rethrow;
    }
  }

  Future<void> updateLastRead(String roomId) async {
    try {
      await _repository.updateLastRead(roomId);
    } catch (error) {
      print('Error updating last read: $error');
    }
  }
}
