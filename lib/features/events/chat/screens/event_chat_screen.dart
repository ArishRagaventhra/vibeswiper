import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:scompass_07/config/routes.dart';
import 'package:scompass_07/config/theme.dart';
import '../../../../shared/widgets/avatar.dart';
import '../../controllers/event_controller.dart';
import '../../models/event_model.dart';
import '../controllers/chat_controller.dart';
import '../controllers/payment_controller.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/event_payment.dart';
import '../models/payment_type.dart';
import '../repository/chat_repository.dart';
import '../widgets/chat_message_input.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/payment_link_banner.dart';
import '../widgets/payment_method_editor.dart';
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
  bool _isOrganizer = false;
  bool _isEventPaid = false;

  // Event name provider and currentUser name to be used for payments
  String _eventName = 'Event';
  String? _userName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).initializeChatRoom(widget.eventId);
      _checkIfOrganizer();
      _loadEventDetails();
    });
    _scrollController.addListener(_scrollListener);
  }

  void _loadEventDetails() async {
    // Get event details for payment note
    try {
      // Use eventDetailsProvider instead of trying to call getEvent on the AsyncValue
      final event = await ref.read(eventDetailsProvider(widget.eventId).future);
      if (event != null && mounted) {
        setState(() {
          _eventName = event.title; // Use title property instead of name
          // Check if the event is paid
          _isEventPaid = event.eventType != EventType.free;
        });
      }
      
      // Get current user's name
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        setState(() {
          _userName = currentUser.userMetadata?['name'] as String? ?? 
                     currentUser.email?.split('@').first;
        });
      }
    } catch (e) {
      debugPrint('Error loading event details: $e');
    }
  }

  Future<void> _checkIfOrganizer() async {
    final isOrganizer = await ref.read(chatControllerProvider.notifier).isEventCreator(widget.eventId);
    if (mounted) {
      setState(() {
        _isOrganizer = isOrganizer;
      });
    }
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
          onPressed: () => context.pop(),
        ),
        title: eventAsync.when(
          data: (event) => Row(
            children: [
              Hero(
                tag: 'event_avatar_${widget.eventId}',
                child: Avatar(
                  url: event?.mediaUrls != null && event!.mediaUrls!.isNotEmpty
                      ? event.mediaUrls!.first
                      : null,
                  size: 32,
                  name: event?.title ?? 'Event',
                  userId: event?.id,
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
          if (_isOrganizer && _isEventPaid)
            IconButton(
              icon: Icon(
                Icons.payment_outlined,
                color: foregroundColor,
                size: 22,
              ),
              tooltip: 'Manage Payment Link',
              onPressed: () => _showPaymentTypeSelectorDialog(widget.eventId),
            ),
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
                  // Payment Link Banner (if available) - Only shown for paid events
                  if (_isEventPaid)
                    ref.watch(eventPaymentsStreamProvider(widget.eventId)).when(
                      data: (payments) {
                        if (payments.isNotEmpty) {
                          return PaymentLinkBanner(
                            payments: payments,
                            isOrganizer: _isOrganizer,
                            eventName: _eventName,
                            userName: _userName,
                            eventId: widget.eventId,
                            onEdit: _isOrganizer
                                ? () => _showPaymentTypeSelectorDialog(widget.eventId)
                                : null,
                            onRemove: _isOrganizer
                                ? (paymentType) => _removePaymentType(widget.eventId, paymentType)
                                : null,
                          );
                        } else if (_isOrganizer) {
                          // Show a button to add payment options for organizers
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.payment_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Add payment methods for participants',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _showPaymentTypeSelectorDialog(widget.eventId),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text('Add'),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return const SizedBox();
                        }
                      },
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final messagesAsync = ref.watch(chatMessagesProvider(chatRoom.id));

                        return messagesAsync.when(
                          data: (messages) {
                            bool hasCurrentUserSentMessage = false;
                            if (messages.isNotEmpty) {
                              hasCurrentUserSentMessage = messages.any((msg) => msg.senderId == currentUserId);
                            }

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
                                    SizedBox(height: size.height * 0.03),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: size.width * 0.1),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Frequently asked questions:',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.hintColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: size.height * 0.015),
                                          Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _buildQuestionPill(
                                                context,
                                                'What is the price?',
                                                theme,
                                                onTap: () => _setAndSendTemplateMessage(
                                                  'What is the price?',
                                                  chatRoom.id,
                                                ),
                                              ),
                                              _buildQuestionPill(
                                                context,
                                                'Where exactly is the location?',
                                                theme,
                                                onTap: () => _setAndSendTemplateMessage(
                                                  'Where exactly is the location?',
                                                  chatRoom.id,
                                                ),
                                              ),
                                              _buildQuestionPill(
                                                context,
                                                'What should I bring?',
                                                theme,
                                                onTap: () => _setAndSendTemplateMessage(
                                                  'What should I bring?',
                                                  chatRoom.id,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Stack(
                              children: [
                                ListView.builder(
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
                                ),
                                if (!hasCurrentUserSentMessage)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            theme.scaffoldBackgroundColor.withOpacity(0),
                                            theme.scaffoldBackgroundColor,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            'Ask a question:',
                                            textAlign: TextAlign.center,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.hintColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Wrap(
                                            alignment: WrapAlignment.center,
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _buildQuestionPill(
                                                context,
                                                'What is the price?',
                                                theme,
                                                onTap: () => _setAndSendTemplateMessage(
                                                  'What is the price?',
                                                  chatRoom.id,
                                                ),
                                              ),
                                              _buildQuestionPill(
                                                context,
                                                'Where exactly is the location?',
                                                theme,
                                                onTap: () => _setAndSendTemplateMessage(
                                                  'Where exactly is the location?',
                                                  chatRoom.id,
                                                ),
                                              ),
                                              _buildQuestionPill(
                                                context,
                                                'What should I bring?',
                                                theme,
                                                onTap: () => _setAndSendTemplateMessage(
                                                  'What should I bring?',
                                                  chatRoom.id,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
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

  void _setAndSendTemplateMessage(String message, String roomId) {
    HapticFeedback.selectionClick();
    ref.read(chatMessagesProvider(roomId).notifier).sendMessage(
      content: message,
      type: MessageType.text,
    );
    _scrollToBottom();
  }

  Future<void> _showPaymentTypeSelectorDialog(String eventId) async {
    // Get existing payments to determine which ones are already added
    final payments = await ref.read(paymentControllerProvider.notifier).getEventPayments(eventId);
    
    // Show payment method editor dialog with both UPI and Razorpay options
    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => PaymentMethodEditor(
          eventId: eventId,
          existingPayments: payments,
          onPaymentUpdated: () {
            // Refresh the payment stream - no need to call manually since we use a stream
          },
        ),
      );
    }
  }

  // Legacy method - now delegated to the PaymentMethodEditor widget
  Future<void> _showPaymentLinkDialog(String eventId, PaymentType paymentType) async {
    // Update to use the new PaymentMethodEditor instead of the deleted PaymentLinkDialog
    final payments = await ref.read(paymentControllerProvider.notifier).getEventPayments(eventId);
    
    if (!mounted) return;
    
    // Use the new payment method editor instead
    await showDialog<void>(
      context: context,
      builder: (context) => PaymentMethodEditor(
        eventId: eventId,
        existingPayments: payments,
        // Pre-select the tab based on the payment type
        initialTabIndex: paymentType == PaymentType.upi ? 0 : 1,
        onPaymentUpdated: () {
          // Refresh happens automatically through stream
        },
      ),
    );
  }
  
  Future<void> _removePaymentType(String eventId, PaymentType paymentType) async {
    try {
      final success = await ref.read(paymentControllerProvider.notifier).removeEventPaymentByType(eventId, paymentType);
      
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getPaymentTypeName(paymentType)} payment removed'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
  
  String _getPaymentTypeName(PaymentType type) {
    switch (type) {
      case PaymentType.upi:
        return 'UPI';
      case PaymentType.razorpay:
        return 'Razorpay';
      case PaymentType.stripe:
        return 'Stripe';
      default:
        return 'Payment link';
    }
  }

  Future<void> _updatePaymentLink(
    String eventId, 
    String paymentInfo, 
    PaymentType paymentType, 
  ) async {
    try {
      final success = await ref.read(paymentControllerProvider.notifier).saveEventPayment(
        eventId: eventId,
        paymentInfo: paymentInfo,
        paymentType: paymentType,
        // Only needed for url type in legacy mode
        paymentProcessor: null,
      );
      
      if (mounted && success != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment details updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update payment details'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildQuestionPill(
    BuildContext context,
    String question,
    ThemeData theme, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGradientStart, // Purple
              AppTheme.primaryGradientEnd,   // Pink
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          question,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
