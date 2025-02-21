import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/forum_constants.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendText;
  final Function(String, Uint8List, String, String) onSendMedia;

  const ChatInput({
    super.key,
    required this.onSendText,
    required this.onSendMedia,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _isComposing = false;
  bool _isAttaching = false;

  void _handleSubmitted(String text) {
    widget.onSendText(text);
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
  }

  Future<void> _handleImageSelection() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      widget.onSendMedia(
        image.name,
        imageBytes,
        ForumConstants.mediaTypeImage,
        'image/jpeg',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _handleVideoSelection() async {
    try {
      final video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video == null) return;

      final videoBytes = await video.readAsBytes();
      widget.onSendMedia(
        video.name,
        videoBytes,
        ForumConstants.mediaTypeVideo,
        'video/mp4',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking video: $e')),
        );
      }
    }
  }

  void _showAttachmentOptions() {
    setState(() => _isAttaching = true);
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Image'),
            onTap: () {
              Navigator.pop(context);
              _handleImageSelection();
            },
          ),
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Video'),
            onTap: () {
              Navigator.pop(context);
              _handleVideoSelection();
            },
          ),
        ],
      ),
    ).whenComplete(() => setState(() => _isAttaching = false));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.attach_file,
                  color: _isAttaching
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: _showAttachmentOptions,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (text) {
                    setState(() {
                      _isComposing = text.isNotEmpty;
                    });
                  },
                  onSubmitted: _isComposing ? _handleSubmitted : null,
                  decoration: const InputDecoration(
                    hintText: 'Type a message',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isComposing
                    ? () => _handleSubmitted(_controller.text)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
