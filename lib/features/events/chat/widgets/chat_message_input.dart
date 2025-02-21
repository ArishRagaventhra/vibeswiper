import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_message.dart';
import '../models/chat_media.dart';
import 'dart:typed_data';

class ChatMessageInput extends ConsumerStatefulWidget {
  final String roomId;
  final VoidCallback onMessageSent;
  final Function(bool)? onTypingStateChanged;

  const ChatMessageInput({
    Key? key,
    required this.roomId,
    required this.onMessageSent,
    this.onTypingStateChanged,
  }) : super(key: key);

  @override
  ConsumerState<ChatMessageInput> createState() => _ChatMessageInputState();
}

class _ChatMessageInputState extends ConsumerState<ChatMessageInput> {
  final TextEditingController _controller = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final _uuid = const Uuid();
  bool _isLoading = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
      widget.onTypingStateChanged?.call(hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(chatMessagesProvider(widget.roomId).notifier).sendMessage(
        content: content,
        type: MessageType.text,
      );
      _controller.clear();
      widget.onMessageSent();
      HapticFeedback.lightImpact();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleImageSelection() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image == null) return;

    setState(() => _isLoading = true);
    String? messageId;
    
    try {
      final bytes = await image.readAsBytes();
      
      // First create a message with loading state
      final message = await ref.read(chatMessagesProvider(widget.roomId).notifier).sendMessage(
        content: 'Uploading image...',
        type: MessageType.image,
      );
      messageId = message.id;

      // Then upload media
      final media = await ref.read(chatControllerProvider.notifier).uploadMedia(
        messageId: message.id,
        filePath: image.path,
        bytes: bytes,
      );

      // Update the message with the uploaded media
      await ref.read(chatMessagesProvider(widget.roomId).notifier).updateMessage(
        message.id,
        content: 'Sent an image',
        media: media,
      );

      widget.onMessageSent();
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Error uploading image: $e');
      
      // If we have a message ID, update it to show the error
      if (messageId != null) {
        try {
          await ref.read(chatMessagesProvider(widget.roomId).notifier).updateMessage(
            messageId,
            content: 'Failed to upload image',
          );
        } catch (updateError) {
          debugPrint('Error updating message after failed upload: $updateError');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image. Please try again.'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _handleImageSelection(),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        keyboardPadding > 0 ? keyboardPadding + 8 : 8,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor.withOpacity(0.1),
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.add_photo_alternate,
                  color: _isLoading
                      ? theme.disabledColor
                      : theme.colorScheme.primary,
                ),
                onPressed: _isLoading ? null : () {
                  HapticFeedback.selectionClick();
                  _handleImageSelection();
                },
              ),
            ),
            SizedBox(width: size.width * 0.02),
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: size.height * 0.15,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: theme.hintColor,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.04,
                      vertical: size.height * 0.015,
                    ),
                    border: InputBorder.none,
                  ),
                  style: theme.textTheme.bodyLarge,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            SizedBox(width: size.width * 0.02),
            Container(
              decoration: BoxDecoration(
                color: _hasText ? theme.colorScheme.primary : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: _isLoading
                    ? SizedBox(
                        width: size.width * 0.05,
                        height: size.width * 0.05,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _hasText
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: _hasText
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                      ),
                onPressed: (_isLoading || !_hasText) ? null : () {
                  HapticFeedback.selectionClick();
                  _sendMessage();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
