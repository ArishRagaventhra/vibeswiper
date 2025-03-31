import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/chat_media.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../profile/providers/profile_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import '../../../../shared/widgets/avatar.dart';

class ChatMessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatMessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderName = message.senderProfile?.username ?? 
                      message.senderProfile?.fullName ?? 
                      'Unknown';
    final avatarUrl = message.senderProfile?.avatarUrl;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: size.height * 0.006,
        horizontal: size.width * 0.02,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Avatar(
              url: avatarUrl,
              size: size.width * 0.1,
              name: senderName,
              userId: message.senderId,
            ),
            SizedBox(width: size.width * 0.02),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: EdgeInsets.only(
                      left: size.width * 0.02,
                      bottom: size.height * 0.004,
                    ),
                    child: Text(
                      senderName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ),
                Container(
                  constraints: BoxConstraints(
                    maxWidth: size.width * 0.7,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: size.width * 0.04,
                    vertical: size.height * 0.01,
                  ),
                  decoration: BoxDecoration(
                    color: isMe
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isMe ? 20 : 4),
                      topRight: Radius.circular(isMe ? 4 : 20),
                      bottomLeft: const Radius.circular(20),
                      bottomRight: const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.type != MessageType.text && message.media != null) ...[
                        _buildMediaPreview(context),
                        SizedBox(height: size.height * 0.008),
                      ],
                      Linkify(
                        onOpen: (link) => _handleLinkTap(context, link.url),
                        text: message.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                        linkStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: isMe
                              ? theme.colorScheme.onPrimary.withOpacity(0.9)
                              : theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        options: const LinkifyOptions(
                          humanize: false,
                          defaultToHttps: true,
                        ),
                      ),
                      SizedBox(height: size.height * 0.004),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTimestamp(message.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: isMe
                                  ? theme.colorScheme.onPrimary.withOpacity(0.7)
                                  : theme.colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          if (isMe) ...[
                            SizedBox(width: size.width * 0.01),
                            Icon(
                              Icons.done_all,
                              size: 14,
                              color: theme.colorScheme.onPrimary.withOpacity(0.7),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe) SizedBox(width: size.width * 0.02),
        ],
      ),
    );
  }

  Widget _buildMediaPreview(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    if (message.media?.url == null) {
      return Container(
        padding: EdgeInsets.all(size.width * 0.02),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: size.width * 0.04,
              color: theme.colorScheme.error,
            ),
            SizedBox(width: size.width * 0.02),
            Text(
              'Media unavailable',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      );
    }

    if (message.type == MessageType.file) {
      return GestureDetector(
        onTap: () => _handleDocumentTap(context),
        child: Container(
          padding: EdgeInsets.all(size.width * 0.03),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(message.media!.mimeType ?? ''),
                size: size.width * 0.08,
                color: theme.colorScheme.primary,
              ),
              SizedBox(width: size.width * 0.03),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.media!.fileName ?? 'Document',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message.media!.fileSize != null)
                      Text(
                        _formatFileSize(message.media!.fileSize!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: size.width * 0.03),
              Icon(
                Icons.download_rounded,
                size: size.width * 0.05,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
            ],
          ),
        ),
      );
    }

    // Handle image preview
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: size.height * 0.2,
          maxWidth: size.width * 0.6,
        ),
        child: Stack(
          children: [
            Image.network(
              message.media!.url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: theme.colorScheme.surface.withOpacity(0.1),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Error loading image: $error');
                debugPrint('Stack trace: $stackTrace');
                return Container(
                  padding: EdgeInsets.all(size.width * 0.02),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: size.width * 0.06,
                        color: theme.colorScheme.error,
                      ),
                      SizedBox(height: size.width * 0.01),
                      Text(
                        'Failed to load image',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      if (!isMe) ...[
                        SizedBox(height: size.width * 0.01),
                        TextButton(
                          onPressed: () {
                            // Trigger a reload by rebuilding the widget
                            (context as Element).markNeedsBuild();
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: size.width * 0.02,
                              vertical: size.height * 0.005,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Retry',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (message.type == MessageType.video)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: size.width * 0.1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('application/pdf')) {
      return Icons.picture_as_pdf;
    } else if (mimeType.startsWith('application/msword') || 
              mimeType.contains('document')) {
      return Icons.description;
    } else if (mimeType.contains('spreadsheet') || 
              mimeType.contains('excel')) {
      return Icons.table_chart;
    } else if (mimeType.startsWith('text/')) {
      return Icons.text_snippet;
    }
    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _handleDocumentTap(BuildContext context) async {
    if (message.media?.url == null) return;

    try {
      final url = message.media!.url;
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening document: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleLinkTap(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening link: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Custom time formatting method that properly handles older messages
  String _formatTimestamp(DateTime messageTime) {
    final now = DateTime.now();
    final difference = now.difference(messageTime);
    
    // For messages less than a minute old
    if (difference.inMinutes < 1) {
      return 'now';
    }
    // For messages less than an hour old
    else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    // For messages less than a day old
    else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    // For messages less than a week old
    else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    // For older messages, use the date
    else {
      return '${messageTime.day}/${messageTime.month}/${messageTime.year}';
    }
  }
}
