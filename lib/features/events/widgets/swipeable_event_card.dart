import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:scompass_07/features/events/models/event_model.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scompass_07/config/theme.dart';
import 'package:intl/intl.dart';

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
  late Size _screenSize;
  Offset _position = Offset.zero;
  bool _showFeedback = false;

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
    _rotate = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(_controller);

    // Add a small delay before showing the card to prevent flickering
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(SwipeableEventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset position and animations when widget updates
    if (oldWidget.event.id != widget.event.id) {
      _position = Offset.zero;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final dx = details.delta.dx;
    final dy = details.delta.dy;
    
    setState(() {
      _position += Offset(dx, dy);
      
      // Calculate rotation based on horizontal movement
      final progress = _position.dx / _screenSize.width;
      _rotate = Tween<double>(
        begin: 0,
        end: 25 * math.pi / 180 * progress,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOut,
        ),
      );
      
      // Show feedback with a smaller threshold (5% of screen width)
      final showFeedbackThreshold = _screenSize.width * 0.05;
      if (_position.dx.abs() > showFeedbackThreshold && !_showFeedback) {
        setState(() => _showFeedback = true);
      } else if (_position.dx.abs() <= showFeedbackThreshold && _showFeedback) {
        setState(() => _showFeedback = false);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!mounted) return;
    
    final x = _position.dx;
    final y = _position.dy;
    final velocity = details.velocity.pixelsPerSecond;
    
    // Adjusted swipe thresholds for better mobile experience
    final swipeThreshold = _screenSize.width / 3.5;
    final velocityThreshold = 500.0;
    final shouldSwipe = x.abs() > swipeThreshold || velocity.dx.abs() > velocityThreshold;
    
    if (shouldSwipe) {
      if (!mounted) return;
      
      final isRight = x > 0;
      final endX = isRight ? _screenSize.width * 1.2 : -_screenSize.width * 1.2;
      final duration = (250 * (1 - (x.abs() / _screenSize.width))).clamp(150, 250);
      
      _controller.duration = Duration(milliseconds: duration.toInt());
      _animation = Tween<Offset>(
        begin: _position,
        end: Offset(endX, y + (velocity.dy / velocity.dx) * endX * 0.2),
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutQuint,
        ),
      );
      
      _rotate = Tween<double>(
        begin: _rotate.value,
        end: (isRight ? 25 : -25) * math.pi / 180,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutQuint,
        ),
      );
      
      _controller.forward().then((_) {
        if (mounted) {
          widget.onSwipe(isRight);
        }
      });
    } else {
      if (!mounted) return;
      
      // Smoother return animation
      _controller.duration = const Duration(milliseconds: 300);
      _animation = Tween<Offset>(
        begin: _position,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutBack,
        ),
      );
      
      _rotate = Tween<double>(
        begin: _rotate.value,
        end: 0,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutBack,
        ),
      );
      
      _controller.forward().then((_) {
        if (mounted) {
          setState(() {
            _position = Offset.zero;
            _showFeedback = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    final isRight = _position.dx > 0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = _animation.value + _position;
        final angle = _rotate.value;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (_) => _controller.stop(),
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTap: widget.onTap,
                child: Transform(
                  transform: Matrix4.identity()
                    ..translate(offset.dx, offset.dy)
                    ..rotateZ(angle),
                  alignment: Alignment.center,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.black.withOpacity(0.1),
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _buildEventImage(),
                        ),
                      ),
                      if (_showFeedback)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isRight 
                                    ? AppTheme.primaryGradientEnd 
                                    : Colors.red).withOpacity(0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) => isRight 
                                ? AppTheme.primaryGradient.createShader(bounds)
                                : LinearGradient(
                                    colors: [Colors.red, Colors.red.shade700],
                                  ).createShader(bounds),
                              child: Icon(
                                isRight ? Icons.favorite_rounded : Icons.close_rounded,
                                color: Colors.white,
                                size: 72,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  Widget _buildDateOrRecurringInfo(BuildContext context) {
    // Check if we have a recurring pattern
    if (widget.event.recurringPattern != null && widget.event.recurringPattern!.isNotEmpty) {
      try {
        // Parse the recurring pattern
        final patternData = json.decode(widget.event.recurringPattern!);
        final type = patternData['type'] as String? ?? 'none';
        
        // Only proceed if we have a valid pattern type that's not 'none'
        if (type != 'none') {
          // Choose the appropriate icon and label based on pattern
          IconData patternIcon;
          String patternLabel;
          Color patternColor = Colors.white;
          
          switch (type) {
            case 'daily':
              patternIcon = Icons.calendar_view_day;
              patternLabel = 'Daily';
              patternColor = Colors.blue.shade300;
              break;
            case 'weekly':
              patternIcon = Icons.calendar_view_week;
              patternLabel = 'Weekly';
              patternColor = Colors.green.shade300;
              break;
            case 'monthly':
              patternIcon = Icons.calendar_view_month;
              patternLabel = 'Monthly';
              patternColor = Colors.purple.shade300;
              break;
            default:
              patternIcon = Icons.repeat;
              patternLabel = 'Recurring';
          }
          
          // Return the recurring pattern indicator
          return Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: patternColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      patternIcon,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      patternLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      } catch (e) {
        // If there's an error parsing the pattern, fall back to standard date display
        debugPrint('Error parsing recurring pattern: $e');
      }
    }
    
    // Fall back to standard date display if no valid recurring pattern
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          color: Colors.white,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          _formatDate(widget.event.startTime),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
          ),
        ),
      ],
    );
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
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.3, 0.7],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (widget.event.description != null) ...[
                    Text(
                      widget.event.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      if (widget.event.location != null) ...[
                        Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            widget.event.location!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(width: 16),
                      _buildDateOrRecurringInfo(context),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.event.eventType == EventType.free 
                            ? Colors.green.withOpacity(0.8)
                            : Color(0xFFDAA520).withOpacity(0.8), // Gold color for PAID events
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.event.eventType == EventType.free 
                            ? 'FREE'
                            : 'PAID',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.event.category != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            widget.event.category!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
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
}
