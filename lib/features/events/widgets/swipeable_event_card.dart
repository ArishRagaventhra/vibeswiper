import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:scompass_07/features/events/models/event_model.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';

class SwipeableEventCard extends StatefulWidget {
  final Event event;
  final Function(bool) onSwipe;
  final VoidCallback onTap;

  const SwipeableEventCard({
    Key? key,
    required this.event,
    required this.onSwipe,
    required this.onTap,
  }) : super(key: key);

  @override
  State<SwipeableEventCard> createState() => _SwipeableEventCardState();
}

class _SwipeableEventCardState extends State<SwipeableEventCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  late Animation<double> _rotate;
  Offset _position = Offset.zero;
  double _opacity = 1.0;
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_controller);
    _rotate = Tween<double>(begin: 0, end: 0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _controller.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
      final x = _position.dx;
      _rotate = Tween<double>(
        begin: 0,
        end: 45 * math.pi / 180 * x / _screenSize.width,
      ).animate(_controller);
      
      // Update opacity based on drag distance
      _opacity = 1 - (x.abs() / (_screenSize.width / 2)).clamp(0.0, 0.5);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final x = _position.dx;
    final y = _position.dy;
    final delta = details.velocity.pixelsPerSecond;
    
    if (x.abs() > _screenSize.width / 3 || delta.dx.abs() > 1000) {
      // Swipe threshold reached
      final isRight = x > 0;
      _animation = Tween<Offset>(
        begin: _position,
        end: Offset(isRight ? _screenSize.width : -_screenSize.width, y),
      ).animate(_controller);
      
      _controller.forward().then((_) {
        widget.onSwipe(isRight);
      });
    } else {
      // Return to center
      _animation = Tween<Offset>(
        begin: _position,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _rotate = Tween<double>(
        begin: _rotate.value,
        end: 0,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward().then((_) {
        setState(() {
          _position = Offset.zero;
          _opacity = 1.0;
        });
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEventImage() {
    debugPrint('Event ID: ${widget.event.id}');
    debugPrint('Media URLs: ${widget.event.mediaUrls}');
    
    if (widget.event.mediaUrls?.isNotEmpty ?? false) {
      final imageUrl = widget.event.mediaUrls!.first;
      debugPrint('Loading image URL: $imageUrl');
      
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) {
                debugPrint('Error loading image: $error for URL: $url');
                return _buildPlaceholder(error: true);
              },
              placeholder: (context, url) => Stack(
                children: [
                  _buildPlaceholder(error: false),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ),
              imageBuilder: (context, imageProvider) {
                debugPrint('Image loaded successfully: $imageUrl');
                return Hero(
                  tag: 'event_image_${widget.event.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
              memCacheWidth: MediaQuery.of(context).size.width.toInt(),
              memCacheHeight: MediaQuery.of(context).size.height.toInt(),
              maxHeightDiskCache: 1024,
              maxWidthDiskCache: 1024,
              cacheKey: 'event_image_${widget.event.id}',
            ),
            // Add a gradient overlay for better text visibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      debugPrint('No media URLs available for event: ${widget.event.id}');
      return _buildPlaceholder(error: false);
    }
  }

  Widget _buildPlaceholder({required bool error}) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.event,
            size: error ? 48 : 64,
            color: error 
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            error ? 'Failed to load image' : 'No image available',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: error 
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = _animation.value + _position;
        final angle = _rotate.value;
        final swipeProgress = (offset.dx.abs() / (_screenSize.width / 2)).clamp(0.0, 1.0);
        final isRight = offset.dx > 0;

        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              margin: EdgeInsets.zero, // Remove all margins
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      onTap: widget.onTap,
                      child: Transform(
                        transform: Matrix4.identity()
                          ..translate(offset.dx, offset.dy)
                          ..rotateZ(angle),
                        alignment: Alignment.center,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8), // Even smaller radius
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Event Image
                                _buildEventImage(),
                                // Gradient overlay
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.5, 1.0],
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.9),
                                      ],
                                    ),
                                  ),
                                ),
                                // Swipe indicators
                                if (swipeProgress > 0.1) ...[
                                  // Join indicator (shows on left when swiping right)
                                  Positioned(
                                    left: 32,
                                    top: 32,
                                    child: Transform.rotate(
                                      angle: -0.5,
                                      child: Opacity(
                                        opacity: isRight ? swipeProgress : 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.green,
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 24 * swipeProgress.clamp(0.0, 1.0),
                                              ),
                                              SizedBox(width: 4 * swipeProgress.clamp(0.0, 1.0)),
                                              Text(
                                                'JOIN',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24 * swipeProgress.clamp(0.0, 1.0),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Pass indicator (shows on right when swiping left)
                                  Positioned(
                                    right: 32,
                                    top: 32,
                                    child: Transform.rotate(
                                      angle: 0.5,
                                      child: Opacity(
                                        opacity: !isRight ? swipeProgress : 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.red,
                                              width: 2,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 24 * swipeProgress.clamp(0.0, 1.0),
                                              ),
                                              SizedBox(width: 4 * swipeProgress.clamp(0.0, 1.0)),
                                              Text(
                                                'PASS',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24 * swipeProgress.clamp(0.0, 1.0),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                // Event Info
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          widget.event.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        if (widget.event.description != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            widget.event.description!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.calendar_today,
                                                      color: Colors.white,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      _formatDate(widget.event.startTime),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (widget.event.location != null) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(20),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.location_on,
                                                        color: Colors.white,
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      ConstrainedBox(
                                                        constraints: BoxConstraints(
                                                          maxWidth: MediaQuery.of(context).size.width * 0.4,
                                                        ),
                                                        child: Text(
                                                          widget.event.location!,
                                                          overflow: TextOverflow.ellipsis,
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
