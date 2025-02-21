import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../constants/forum_constants.dart';
import '../models/forum_message.dart';
import '../models/forum_message_media.dart';
import '../providers/forum_providers.dart';
import '../routes/forum_routes.dart';
import '../widgets/chat_input.dart';
import '../widgets/message_bubble.dart';
import 'package:intl/intl.dart'; // Add this line

class ForumChatScreen extends ConsumerStatefulWidget {
  final String forumId;

  const ForumChatScreen({
    super.key,
    required this.forumId,
  });

  @override
  ConsumerState<ForumChatScreen> createState() => _ForumChatScreenState();
}

class _ForumChatScreenState extends ConsumerState<ForumChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;

    final messages = ref.read(forumMessagesProvider(widget.forumId)).value;
    if (messages == null || messages.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      await ref
          .read(forumMessagesProvider(widget.forumId).notifier)
          .loadMore(messages.last.createdAt);
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    try {
      final message = ForumMessage(
        id: const Uuid().v4(),  // Generate a temporary UUID
        forumId: widget.forumId,
        senderId: '',  // Will be set by repository
        content: content,
        messageType: ForumConstants.messageTypeText,
        isPinned: false,
        isAnnouncement: false,
        createdAt: DateTime.now(),
        metadata: {},
      );

      await ref
          .read(forumMessagesProvider(widget.forumId).notifier)
          .sendMessage(message);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _sendMediaMessage(
    String fileName,
    Uint8List fileBytes,
    String mediaType,
    String mimeType,
  ) async {
    try {
      // First, create a message with a UUID
      final messageId = const Uuid().v4();
      final message = ForumMessage(
        id: messageId,  // Use generated UUID
        forumId: widget.forumId,
        senderId: '',  // Will be set by repository
        messageType: mediaType,
        isPinned: false,
        isAnnouncement: false,
        createdAt: DateTime.now(),
        metadata: {},
      );

      final sentMessage = await ref
          .read(forumMessagesProvider(widget.forumId).notifier)
          .sendMessage(message);

      if (!mounted) return;

      // Then, upload the media with a UUID
      final mediaId = const Uuid().v4();
      final media = ForumMessageMedia(
        id: mediaId,  // Use generated UUID
        messageId: sentMessage.id,
        url: '',  // Will be set after upload
        type: mediaType,
        fileName: fileName,
        fileSize: fileBytes.length,
        mimeType: mimeType,
        createdAt: DateTime.now(),
        metadata: {},
      );

      await ref.read(forumRepositoryProvider).uploadMedia(media, fileBytes);

      // Trigger a state update or re-fetch messages to reflect the new media in the UI
      ref.refresh(forumMessagesProvider(widget.forumId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending media: $e')),
        );
      }
    }
  }

  void _showMessageOptions(ForumMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.push_pin),
            title: Text(message.isPinned ? 'Unpin Message' : 'Pin Message'),
            onTap: () {
              context.pop();
              ref
                  .read(forumMessagesProvider(widget.forumId).notifier)
                  .pinMessage(message.id, !message.isPinned);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Message'),
            onTap: () {
              context.pop();
              ref
                  .read(forumMessagesProvider(widget.forumId).notifier)
                  .deleteMessage(message.id);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? Colors.black : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;
    final surfaceColor = isDark 
        ? theme.colorScheme.surface 
        : theme.colorScheme.surfaceVariant.withOpacity(0.5);

    final messagesAsync = ref.watch(forumMessagesProvider(widget.forumId));
    final forumAsync = ref.watch(forumProvider(widget.forumId));

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: foregroundColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Hero(
              tag: 'forum_avatar_${widget.forumId}',
              child: forumAsync.when(
                data: (forum) => CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage: forum?.profileImageUrl != null
                      ? NetworkImage(forum!.profileImageUrl!)
                      : null,
                  child: forum?.profileImageUrl == null
                      ? Text(
                          forum?.name.substring(0, 1).toUpperCase() ?? 'F',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                loading: () => CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Text(
                    'F',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                error: (_, __) => CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: forumAsync.when(
                data: (forum) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      forum?.name ?? 'Forum Chat',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (forum?.description != null)
                      Text(
                        forum!.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foregroundColor.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                loading: () => Text(
                  'Loading...',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foregroundColor,
                  ),
                ),
                error: (_, __) => Text(
                  'Error',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: foregroundColor,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.group_outlined,
              color: foregroundColor,
            ),
            onPressed: () => context.push(
              ForumRoutes.forumMembers.replaceFirst(':forumId', widget.forumId),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: foregroundColor,
            ),
            onPressed: () => context.push(
              ForumRoutes.forumSettings.replaceFirst(':forumId', widget.forumId),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pinned Messages Bar (if any)
          messagesAsync.when(
            data: (messages) {
              final pinnedMessages = messages.where((m) => m.isPinned).toList();
              if (pinnedMessages.isEmpty) return const SizedBox.shrink();
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.push_pin,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${pinnedMessages.length} pinned message${pinnedMessages.length > 1 ? 's' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      iconSize: 20,
                      color: theme.colorScheme.primary,
                      onPressed: () {
                        // TODO: Show pinned messages dialog
                      },
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          // Messages List
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: messagesAsync.when(
                data: (messages) => messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: theme.colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 20,
                        ),
                        itemCount: messages.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          final message = messages[index];
                          final showDate = index == messages.length - 1 ||
                              !_isSameDay(
                                message.createdAt,
                                messages[index + 1].createdAt,
                              );

                          return Column(
                            children: [
                              if (showDate) ...[
                                const SizedBox(height: 16),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant
                                          .withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _formatMessageDate(message.createdAt),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              MessageBubble(
                                message: message,
                                onLongPress: () => _showMessageOptions(message),
                              ),
                            ],
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Text('Error: $error'),
                ),
              ),
            ),
          ),
          
          // Chat Input
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: ChatInput(
                onSendText: _sendMessage,
                onSendMedia: (name, bytes, mediaType, mimeType) => _sendMediaMessage(
                  name,
                  bytes,
                  mediaType,
                  mimeType,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date); // e.g., "Monday"
    } else {
      return DateFormat('MMM d, y').format(date); // e.g., "Mar 15, 2024"
    }
  }
}
