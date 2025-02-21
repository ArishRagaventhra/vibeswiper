import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/forum.dart';
import '../models/forum_member.dart';
import '../models/forum_message.dart';
import '../repositories/forum_repository.dart';

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  return ForumRepository(Supabase.instance.client);
});

// Provider to track which forum is currently being joined
final joiningForumProvider = StateProvider<String?>((ref) => null);

// Provider for forums created by the user
final createdForumsProvider = AsyncNotifierProvider<CreatedForumsNotifier, List<Forum>>(() {
  return CreatedForumsNotifier();
});

class CreatedForumsNotifier extends AsyncNotifier<List<Forum>> {
  @override
  Future<List<Forum>> build() async {
    final repository = ref.read(forumRepositoryProvider);
    return repository.getCreatedForums();
  }

  void removeForum(String forumId) {
    state.whenData((forums) {
      state = AsyncData(forums.where((forum) => forum.id != forumId).toList());
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => 
      ref.read(forumRepositoryProvider).getCreatedForums()
    );
  }
}

// Provider for forums joined by the user (excluding created ones)
final joinedForumsProvider = AsyncNotifierProvider<JoinedForumsNotifier, List<Forum>>(() {
  return JoinedForumsNotifier();
});

class JoinedForumsNotifier extends AsyncNotifier<List<Forum>> {
  @override
  Future<List<Forum>> build() async {
    final repository = ref.read(forumRepositoryProvider);
    return repository.getJoinedForums();
  }

  void removeForum(String forumId) {
    state.whenData((forums) {
      state = AsyncData(forums.where((forum) => forum.id != forumId).toList());
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => 
      ref.read(forumRepositoryProvider).getJoinedForums()
    );
  }
}

// Provider for all forums (for discover tab)
final allForumsProvider = AsyncNotifierProvider<AllForumsNotifier, List<Forum>>(() {
  return AllForumsNotifier();
});

class AllForumsNotifier extends AsyncNotifier<List<Forum>> {
  @override
  Future<List<Forum>> build() async {
    final repository = ref.read(forumRepositoryProvider);
    return repository.getAllForums();
  }

  void removeForum(String forumId) {
    state.whenData((forums) {
      state = AsyncData(forums.where((forum) => forum.id != forumId).toList());
    });
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => 
      ref.read(forumRepositoryProvider).getAllForums()
    );
  }
}

// Provider to check if user is a member of a forum
final forumMembershipProvider = FutureProvider.family<bool, String>((ref, forumId) async {
  final repository = ref.read(forumRepositoryProvider);
  return repository.isForumMember(forumId);
});

// Provider to get a single forum by ID
final forumProvider = FutureProvider.family<Forum, String>((ref, forumId) async {
  final repository = ref.read(forumRepositoryProvider);
  final forums = await repository.getForumById(forumId);
  if (forums == null) {
    throw 'Forum not found';
  }
  return forums;
});

// Provider to handle forum deletion
final forumDeletionProvider = FutureProvider.autoDispose.family<void, String>((ref, forumId) async {
  final repository = ref.read(forumRepositoryProvider);
  
  // First update the UI state
  ref.read(createdForumsProvider.notifier).removeForum(forumId);
  ref.read(joinedForumsProvider.notifier).removeForum(forumId);
  ref.read(allForumsProvider.notifier).removeForum(forumId);
  
  // Then delete from database
  await repository.deleteForum(forumId);
  
  // Force refresh all providers to ensure consistency
  await Future.wait([
    ref.read(createdForumsProvider.notifier).refresh(),
    ref.read(joinedForumsProvider.notifier).refresh(),
    ref.read(allForumsProvider.notifier).refresh(),
  ]);
});

final forumMembersProvider = AsyncNotifierProviderFamily<ForumMembersNotifier, List<ForumMember>, String>(() {
  return ForumMembersNotifier();
});

class ForumMembersNotifier extends FamilyAsyncNotifier<List<ForumMember>, String> {
  @override
  Future<List<ForumMember>> build(String forumId) async {
    state = const AsyncValue.loading();
    try {
      return await ref.read(forumRepositoryProvider).getForumMembers(forumId);
    } catch (e, stack) {
      return AsyncValue.error(e, stack).when(
        data: (_) => [],
        error: (_, __) => [],
        loading: () => [],
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final members = await ref.read(forumRepositoryProvider).getForumMembers(arg);
      state = AsyncValue.data(members);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final forumMessagesProvider = AsyncNotifierProviderFamily<ForumMessagesNotifier, List<ForumMessage>, String>(() {
  return ForumMessagesNotifier();
});

class ForumMessagesNotifier extends FamilyAsyncNotifier<List<ForumMessage>, String> {
  RealtimeChannel? _subscription;
  // Track recently sent message IDs to prevent duplicates
  final Set<String> _recentlySentMessageIds = {};

  @override
  Future<List<ForumMessage>> build(String forumId) async {
    // Cancel any existing subscription when rebuilding
    _subscription?.unsubscribe();
    
    state = const AsyncValue.loading();
    try {
      // Initial fetch
      final messages = await ref.read(forumRepositoryProvider).getForumMessages(forumId);
      
      // Setup realtime subscription for both inserts and updates
      _subscription = Supabase.instance.client
          .channel('forum_messages_$forumId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'forum_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'forum_id',
              value: forumId,
            ),
            callback: (payload) {
              if (payload.newRecord != null) {
                final newMessage = ForumMessage.fromJson(
                  Map<String, dynamic>.from(payload.newRecord!),
                );
                // Skip if this is a message we just sent
                if (_recentlySentMessageIds.contains(newMessage.id)) {
                  _recentlySentMessageIds.remove(newMessage.id);
                  return;
                }
                final currentMessages = state.value ?? [];
                state = AsyncValue.data([newMessage, ...currentMessages]);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'forum_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'forum_id',
              value: forumId,
            ),
            callback: (payload) async {
              if (payload.newRecord != null) {
                final messageId = payload.newRecord!['id'] as String;
                // Fetch the updated message with media
                final updatedMessage = await ref
                    .read(forumRepositoryProvider)
                    .getMessageWithMedia(messageId);

                if (updatedMessage != null) {
                  final currentMessages = state.value ?? [];
                  state = AsyncValue.data([
                    for (final msg in currentMessages)
                      if (msg.id == updatedMessage.id) updatedMessage else msg
                  ]);
                }
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'forum_message_media',
            callback: (payload) async {
              if (payload.newRecord != null) {
                final messageId = payload.newRecord!['message_id'] as String;
                // Fetch the updated message with media
                final updatedMessage = await ref
                    .read(forumRepositoryProvider)
                    .getMessageWithMedia(messageId);

                if (updatedMessage != null) {
                  final currentMessages = state.value ?? [];
                  state = AsyncValue.data([
                    for (final msg in currentMessages)
                      if (msg.id == updatedMessage.id) updatedMessage else msg
                  ]);
                }
              }
            },
          )
          .subscribe();

      ref.onDispose(() {
        _subscription?.unsubscribe();
      });

      return messages;
    } catch (e, stack) {
      return AsyncValue.error(e, stack).when(
        data: (_) => [],
        error: (_, __) => [],
        loading: () => [],
      );
    }
  }

  Future<void> loadMore(DateTime before) async {
    final currentMessages = state.value ?? [];
    try {
      final newMessages = await ref.read(forumRepositoryProvider).getForumMessages(
        arg,
        before: before,
      );
      state = AsyncValue.data([...currentMessages, ...newMessages]);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<ForumMessage> sendMessage(ForumMessage message) async {
    final repository = ref.read(forumRepositoryProvider);
    try {
      final newMessage = await repository.sendMessage(message);
      // Track this message ID to prevent duplicate from real-time update
      _recentlySentMessageIds.add(newMessage.id);
      final currentMessages = state.value ?? [];
      state = AsyncValue.data([newMessage, ...currentMessages]);
      return newMessage;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await ref.read(forumRepositoryProvider).deleteMessage(messageId);
      final currentMessages = state.value ?? [];
      state = AsyncValue.data(
        currentMessages.map((message) {
          if (message.id == messageId) {
            return ForumMessage.fromJson({
              ...message.toJson(),
              'deleted_at': DateTime.now().toIso8601String(),
            });
          }
          return message;
        }).toList(),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> pinMessage(String messageId, bool isPinned) async {
    try {
      await ref.read(forumRepositoryProvider).pinMessage(messageId, isPinned);
      final currentMessages = state.value ?? [];
      state = AsyncValue.data(
        currentMessages.map((message) {
          if (message.id == messageId) {
            return ForumMessage.fromJson({
              ...message.toJson(),
              'is_pinned': isPinned,
            });
          }
          return message;
        }).toList(),
      );
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
