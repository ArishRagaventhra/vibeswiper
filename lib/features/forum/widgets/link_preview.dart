import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

class LinkPreview extends StatefulWidget {
  final String url;
  final bool isCurrentUser;

  const LinkPreview({
    super.key,
    required this.url,
    required this.isCurrentUser,
  });

  @override
  State<LinkPreview> createState() => _LinkPreviewState();
}

class _LinkPreviewState extends State<LinkPreview> {
  Metadata? _metadata;
  bool _isLoading = true;
  String? _errorMessage;
  String? _thumbnailUrl;

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  String? _getYouTubeVideoId(String url) {
    final uri = Uri.parse(url);
    if (uri.host.contains('youtube.com') || uri.host.contains('youtu.be')) {
      if (uri.host.contains('youtube.com')) {
        return uri.queryParameters['v'];
      } else {
        return uri.pathSegments.last.split('?').first;
      }
    }
    return null;
  }

  Future<void> _fetchMetadata() async {
    try {
      final videoId = _getYouTubeVideoId(widget.url);
      if (videoId != null) {
        // Handle YouTube links
        _thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
        final response = await http.get(Uri.parse(widget.url));
        final document = parse(response.body);
        final metadata = await MetadataParser.parse(document);
        if (mounted) {
          setState(() {
            _metadata = metadata;
            _isLoading = false;
          });
        }
      } else {
        // Handle other links
        final metadata = await MetadataFetch.extract(widget.url);
        if (mounted) {
          setState(() {
            _metadata = metadata;
            _thumbnailUrl = metadata?.image;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load preview';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchUrl() async {
    try {
      final uri = Uri.parse(widget.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch ${widget.url}';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: widget.isCurrentUser
              ? theme.colorScheme.primary.withOpacity(0.7)
              : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_errorMessage != null || _metadata == null) {
      return GestureDetector(
        onTap: _launchUrl,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isCurrentUser
                ? theme.colorScheme.primary.withOpacity(0.7)
                : theme.colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: Icon(
              Icons.link,
              color: widget.isCurrentUser
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
            title: Text(
              widget.url,
              style: theme.textTheme.bodySmall?.copyWith(
                color: widget.isCurrentUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _launchUrl,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isCurrentUser
              ? theme.colorScheme.primary.withOpacity(0.7)
              : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_thumbnailUrl != null)
                SizedBox(
                  width: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: _thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: theme.colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.image,
                            color: widget.isCurrentUser
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      if (_getYouTubeVideoId(widget.url) != null)
                        Container(
                          color: Colors.black26,
                          child: Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 40,
                              color: theme.colorScheme.surface,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_metadata?.title != null) ...[
                        Text(
                          _metadata!.title!,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: widget.isCurrentUser
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (_metadata?.description != null)
                        Text(
                          _metadata!.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: widget.isCurrentUser
                                ? theme.colorScheme.onPrimary.withOpacity(0.7)
                                : theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        Uri.parse(widget.url).host,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.isCurrentUser
                              ? theme.colorScheme.onPrimary.withOpacity(0.5)
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
