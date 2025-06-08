import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:ui';
import '../models/event_model.dart';
import '../utils/recurring_event_utils.dart';

class EventListItem extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool isGridView;

  const EventListItem({
    Key? key,
    required this.event,
    this.onTap,
    this.isGridView = false,
  }) : super(key: key);

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Date TBD';
    return DateFormat('MMM d, y • h:mm a').format(dateTime);
  }
  
  // Helper method to get recurring pattern display info
  Map<String, dynamic> _getRecurringPatternInfo(String patternJson) {
    // Use the utility class to get comprehensive recurring event information
    return RecurringEventUtils.getNextOccurrenceInfo(event);
  }

  String _getTimeUntilEvent(DateTime? eventDate) {
    // Return a default message if the event date is null
    if (eventDate == null) {
      return 'Date TBD';
    }
    // For recurring events, we need to calculate the next occurrence
    DateTime dateToCheck = eventDate;
    bool isCompleted = false;
    
    if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty) {
      // Get info about the next occurrence
      final occurrenceInfo = RecurringEventUtils.getNextOccurrenceInfo(event);
      dateToCheck = occurrenceInfo['nextOccurrence'];
      isCompleted = occurrenceInfo['isCompleted'];
      
      // If the event series is completed, show "Event ended"
      if (isCompleted) {
        return 'Event ended';
      }
    }
    
    final now = DateTime.now();
    final difference = dateToCheck.difference(now);

    // For non-recurring events or if the next occurrence is in the past
    if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty && !isCompleted && difference.isNegative) {
      // This shouldn't happen often since we're calculating the next occurrence,
      // but just in case, recalculate to get a fresh next occurrence
      final freshOccurrence = RecurringEventUtils.calculateNextOccurrence(event);
      final freshDifference = freshOccurrence.difference(now);
      
      if (freshDifference.isNegative) {
        return 'Event ended';
      } else if (freshDifference.inDays > 30) {
        return '${(freshDifference.inDays / 30).floor()} months left';
      } else if (freshDifference.inDays > 0) {
        return '${freshDifference.inDays} days left';
      } else if (freshDifference.inHours > 0) {
        return '${freshDifference.inHours} hours left';
      } else {
        return '${freshDifference.inMinutes} minutes left';
      }
    }
    
    // Standard time difference calculation
    if (difference.isNegative) {
      return 'Event ended';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months left';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days left';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours left';
    } else {
      return '${difference.inMinutes} minutes left';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isGridView ? 0 : 12, 
        vertical: isGridView ? 0 : 8
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // Outer shadow
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          // Inner highlight for depth
          BoxShadow(
            color: isDarkMode
                ? Colors.white.withOpacity(0.03)
                : Colors.white.withOpacity(0.5),
            offset: const Offset(0, 1),
            blurRadius: 1,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(
          color: isDarkMode 
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.03),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => context.go('/events/${event.id}'),
          child: isGridView ? _buildGridItem(theme) : _buildListItem(theme),
        ),
      ),
    );
  }
  
  Widget _buildGridItem(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final imageHeight = availableHeight * 0.6; // Increased to 60% for better visuals

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event image with price badge
            SizedBox(
              height: imageHeight,
              child: Stack(
          children: [
            // Image with gradient overlay
            Hero(
              tag: 'event_image_${event.id}_grid',
              child: Container(
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Event image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: event.mediaUrls?.isNotEmpty ?? false
                        ? Image.network(
                            event.mediaUrls!.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildGridPlaceholder(theme);
                            },
                          )
                        : _buildGridPlaceholder(theme),
                    ),
                          // Enhanced gradient overlay
                          Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                                  Colors.black.withOpacity(0.2),
                                  Colors.black.withOpacity(0.5),
                            ],
                                stops: const [0.5, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
                  // Price badge with glass effect
            Positioned(
                    top: 12,
                    left: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                            color: (event.eventType == EventType.free 
                    ? theme.colorScheme.primary 
                              : theme.colorScheme.secondary).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                    ),
                ),
                child: Text(
                  event.eventType == EventType.free 
                    ? 'FREE' 
                    : '₹${event.ticketPrice?.toStringAsFixed(0) ?? '0'}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            
                  // Time remaining badge with glass effect
            Positioned(
                    top: 12,
                    right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                    ),
                ),
                          child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                                _getTimeUntilEvent(event.startTime),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                          ),
              ),
            ),
                        ),
                      ),
                    ],
                  ),
                ),
            
            // Content area with glass effect background
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.9),
                      border: Border(
                        top: BorderSide(
                          color: theme.dividerColor.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                        // Title with enhanced typography
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.6,
                ),
                child: Text(
                  event.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
                        const SizedBox(height: 6),
              
                        // Category with modern styling
                        if (event.category != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(event.category!).withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(event.category!),
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    event.category!,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 8),
                        
                        // Description with improved styling
                        Flexible(
                          child: Text(
                            event.description ?? '',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        ),
      ],
        );
      },
    );
  }
  
  Widget _buildListItem(ThemeData theme) {
    final isDarkMode = theme.brightness == Brightness.dark;
  
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Enhanced image container with gradient overlay
          SizedBox(
            height: 240, // Increased height for better viewing
            width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Main event image
                  Hero(
                    tag: 'event_image_${event.id}',
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: event.mediaUrls?.isNotEmpty ?? false
                        ? Image.network(
                            event.mediaUrls!.first,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildPlaceholder(theme);
                            },
                          )
                        : _buildPlaceholder(theme),
                    ),
                  ),
                  // Gradient overlay for improved text readability
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Price badge (top-left)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: event.eventType == EventType.free 
                    ? theme.colorScheme.primary
                    : theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  event.eventType == EventType.free 
                    ? 'FREE' 
                    : '₹${event.ticketPrice?.toStringAsFixed(0) ?? '0'}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            
            // Time remaining badge (top-right)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      // Use the first occurrence date for time remaining calculation with fallback
                      () {
                        if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty) {
                          final patternInfo = _getRecurringPatternInfo(event.recurringPattern!);
                          // Calculate next occurrence directly if firstOccurrence isn't available
                          final occurrenceDate = patternInfo.containsKey('firstOccurrence') && patternInfo['firstOccurrence'] != null
                              ? patternInfo['firstOccurrence'] as DateTime
                              : RecurringEventUtils.calculateNextOccurrence(event);
                          return _getTimeUntilEvent(occurrenceDate);
                        } else {
                          return _getTimeUntilEvent(event.startTime);
                        }
                      }(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Recurring event badge (if applicable)
            if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty)
              Positioned(
                bottom: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getRecurringPatternInfo(event.recurringPattern!)['color'].withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getRecurringPatternInfo(event.recurringPattern!)['icon'],
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getRecurringPatternInfo(event.recurringPattern!)['label'],
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event title with enhanced typography
              Text(
                event.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  letterSpacing: -0.3,
                  fontSize: 22,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Category with modern styling
              if (event.category != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(event.category!).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getCategoryColor(event.category!).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getCategoryIcon(event.category!),
                        size: 16,
                        color: _getCategoryColor(event.category!),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event.category!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: _getCategoryColor(event.category!),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Description with improved styling
              if (event.description != null) ...[
                const SizedBox(height: 14),
                Text(
                  event.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                    fontSize: 14,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 20),
              // Event details section with modern design
              Container(
                margin: const EdgeInsets.only(top: 5), // Add margin for spacing
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Date & Time row with enhanced recurring event display
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Calendar icon with pattern-specific styling
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                ? _getRecurringPatternInfo(event.recurringPattern!)['color'].withOpacity(0.15)
                                : theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                ? _getRecurringPatternInfo(event.recurringPattern!)['icon']
                                : Icons.calendar_today_rounded,
                              size: 20,
                              color: event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                ? _getRecurringPatternInfo(event.recurringPattern!)['color']
                                : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Enhanced header for recurring events
                                Text(
                                  event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                    ? 'Recurring Event'
                                    : 'Date & Time',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                      ? _getRecurringPatternInfo(event.recurringPattern!)['color']
                                      : theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                
                                // Recurring pattern display with modern badge
                                if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty) ...[                                
                                  Row(
                                    children: [
                                      // Pattern type badge (Daily, Weekly, Monthly)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: _getRecurringPatternInfo(event.recurringPattern!)['color'].withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: _getRecurringPatternInfo(event.recurringPattern!)['color'].withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          _getRecurringPatternInfo(event.recurringPattern!)['label'],
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: _getRecurringPatternInfo(event.recurringPattern!)['color'],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      // First occurrence with countdown
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Text(
                                              _getRecurringPatternInfo(event.recurringPattern!).containsKey('firstOccurrence')
                                                ? DateFormat('E, MMM d • ').format(_getRecurringPatternInfo(event.recurringPattern!)['firstOccurrence'] as DateTime) +
                                                  _getTimeUntilEvent(_getRecurringPatternInfo(event.recurringPattern!)['firstOccurrence'] as DateTime?)
                                                : 'Date TBD',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[                              
                                  Text(
                                  event.startTime != null ? _formatDateTime(event.startTime) : 'Date TBD',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Divider
                    if (event.location != null)
                      Divider(height: 1, thickness: 1, color: theme.colorScheme.outline.withOpacity(0.1)),
                    // Location display with modern design
                    if (event.location != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.place_rounded,
                                size: 20,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Location',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: theme.colorScheme.secondary,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    event.location!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Enhanced tags section
              if (event.tags.isNotEmpty) ...[
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'Tags',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: event.tags.map((tag) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.shadowColor.withOpacity(0.05),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '#',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary.withOpacity(0.7),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  tag,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Icon(
          Icons.event,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
  
  Widget _buildGridPlaceholder(ThemeData theme) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Center(
        child: Icon(
          Icons.event,
          size: 36,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Color _getStatusColor(EventStatus status) {
    switch (status) {
      case EventStatus.upcoming:
        return Colors.green;
      case EventStatus.ongoing:
        return Colors.blue;
      case EventStatus.completed:
        return Colors.grey;
      case EventStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusPillColor(DateTime? eventDate, EventStatus status) {
    // For recurring events, we need different logic
    if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty) {
      final occurrenceInfo = RecurringEventUtils.getNextOccurrenceInfo(event);
      final isCompleted = occurrenceInfo['isCompleted'];
      
      if (isCompleted) {
        return Colors.red; // Show red for completed recurring events
      }
      
      // Use the next occurrence date for color determination
      final nextDate = occurrenceInfo['nextOccurrence'];
      if (nextDate != null) {
        final now = DateTime.now();
        
        if (nextDate.isBefore(now)) {
          return Colors.red; // Show red if next occurrence is in the past
        }
      }
    } else if (eventDate != null) {
      // Standard logic for non-recurring events
      final now = DateTime.now();
      if (eventDate.isBefore(now)) {
        return Colors.red; // Show red for any ended event
      }
    }
    
    // Otherwise, use the regular status color
    return _getStatusColor(status);
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'biking':
        return const Color(0xFF1E88E5); // Vibrant blue
      case 'hiking':
        return const Color(0xFF43A047); // Forest green
      case 'running':
        return const Color(0xFFE53935); // Energetic red
      case 'swimming':
        return const Color(0xFF039BE5); // Ocean blue
      case 'yoga':
        return const Color(0xFF8E24AA); // Calm purple
      case 'sports':
        return const Color(0xFFFF6F00); // Dynamic orange
      case 'music':
        return const Color(0xFF6200EA); // Deep purple
      case 'art':
        return const Color(0xFFD81B60); // Creative pink
      case 'water activities':
        return const Color(0xFF00ACC1); // Teal blue
      case 'adventure activities':
        return const Color(0xFFFF6D00); // Orange
      default:
        return const Color(0xFF78909C); // Neutral blue-grey
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'biking':
        return Icons.directions_bike;
      case 'hiking':
        return Icons.terrain;
      case 'running':
        return Icons.directions_run;
      case 'swimming':
        return Icons.pool;
      case 'yoga':
        return Icons.self_improvement;
      case 'sports':
        return Icons.sports;
      case 'music':
        return Icons.music_note;
      case 'art':
        return Icons.palette;
      case 'water activities':
        return Icons.water;
      case 'adventure activities':
        return Icons.landscape;
      default:
        return Icons.local_activity;
    }
  }
}
