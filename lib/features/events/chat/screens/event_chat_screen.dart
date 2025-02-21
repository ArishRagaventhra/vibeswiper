import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/config/routes.dart';
import '../../controllers/event_controller.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../repository/chat_repository.dart';
import '../widgets/chat_message_input.dart';
import '../widgets/chat_message_bubble.dart';
import '../../providers/event_providers.dart';

class EventChatScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventChatScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  ConsumerState<EventChatScreen> createState() => _EventChatScreenState();
}

class _EventChatScreenState extends ConsumerState<EventChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).initializeChatRoom(widget.eventId);
    });
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final isNotAtBottom = _scrollController.position.pixels > 100;
      if (isNotAtBottom != _showScrollToBottom) {
        setState(() => _showScrollToBottom = isNotAtBottom);
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
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

    final chatRoomAsync = ref.watch(chatRoomProvider(widget.eventId));
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));
    final size = MediaQuery.of(context).size;
    
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
        title: eventAsync.when(
          data: (event) => Row(
            children: [
              Hero(
                tag: 'event_avatar_${widget.eventId}',
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  backgroundImage: event?.mediaUrls != null && event!.mediaUrls!.isNotEmpty
                      ? NetworkImage(event.mediaUrls!.first)
                      : null,
                  child: event?.mediaUrls == null || event!.mediaUrls!.isEmpty
                      ? Icon(
                          Icons.event,
                          color: theme.colorScheme.primary,
                          size: 20,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event?.title ?? 'Event Chat',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: foregroundColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (event?.description != null)
                      Text(
                        event!.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: foregroundColor.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          error: (error, _) => Text(
            'Error',
            style: theme.textTheme.titleMedium?.copyWith(
              color: foregroundColor,
            ),
          ),
          loading: () => Text(
            'Loading...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: foregroundColor,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.group_outlined,
              color: foregroundColor,
              size: 24,
            ),
            tooltip: 'View Participants',
            onPressed: () => context.push(
              AppRoutes.eventParticipants.replaceFirst(':eventId', widget.eventId),
            ),
          ),
        ],
      ),
      body: chatRoomAsync.when(
        data: (chatRoom) {
          if (chatRoom == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: size.height * 0.02),
                  const Text('Initializing chat room...'),
                ],
              ),
            );
          }

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final messagesAsync = ref.watch(chatMessagesProvider(chatRoom.id));

                        return messagesAsync.when(
                          data: (messages) {
                            if (messages.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: size.width * 0.15,
                                      color: theme.disabledColor.withOpacity(0.3),
                                    ),
                                    SizedBox(height: size.height * 0.02),
                                    Text(
                                      'No messages yet',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.disabledColor,
                                      ),
                                    ),
                                    SizedBox(height: size.height * 0.01),
                                    Text(
                                      'Start the conversation!',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.disabledColor,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: EdgeInsets.symmetric(
                                horizontal: size.width * 0.04,
                                vertical: size.height * 0.02,
                              ),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final message = messages[index];
                                final showDate = index == messages.length - 1 ||
                                    !_isSameDay(message.createdAt, messages[index + 1].createdAt);
                                
                                return Column(
                                  children: [
                                    if (showDate)
                                      Padding(
                                        padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
                                        child: Center(
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: size.width * 0.03,
                                              vertical: size.height * 0.006,
                                            ),
                                            decoration: BoxDecoration(
                                              color: theme.dividerColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _formatMessageDate(message.createdAt),
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ChatMessageBubble(
                                      message: message,
                                      isMe: message.senderId == currentUserId,
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (error, stack) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: size.width * 0.15,
                                  color: theme.colorScheme.error,
                                ),
                                SizedBox(height: size.height * 0.02),
                                Text(
                                  'Error loading messages',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    ref.refresh(chatMessagesProvider(chatRoom.id));
                                  },
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SafeArea(
                    child: ChatMessageInput(
                      roomId: chatRoom.id,
                      onMessageSent: _scrollToBottom,
                      onTypingStateChanged: (isTyping) {
                        setState(() => _isTyping = isTyping);
                      },
                    ),
                  ),
                ],
              ),
              if (_showScrollToBottom)
                Positioned(
                  right: size.width * 0.04,
                  bottom: size.height * 0.1,
                  child: FloatingActionButton.small(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _scrollToBottom();
                    },
                    elevation: 2,
                    backgroundColor: theme.colorScheme.surface,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              SizedBox(height: size.height * 0.02),
              Text('Error: $error'),
              TextButton(
                onPressed: () {
                  ref.refresh(chatRoomProvider(widget.eventId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
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
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
