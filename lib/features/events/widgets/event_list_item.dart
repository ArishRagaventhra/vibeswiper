import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/event_model.dart';

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

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y • h:mm a').format(dateTime);
  }
  
  // Helper method to get recurring pattern display info
  Map<String, dynamic> _getRecurringPatternInfo(String patternJson) {
    try {
      final Map<String, dynamic> result = {
        'hasPattern': false,
        'icon': Icons.calendar_today,
        'label': '',
        'color': Colors.grey,
        'firstOccurrence': event.startTime,
        'patternData': null,
      };
      
      final patternData = json.decode(patternJson);
      final type = patternData['type'] as String? ?? 'none';
      
      if (type == 'none') return result;
      
      result['hasPattern'] = true;
      result['patternData'] = patternData;
      
      // Calculate first occurrence date for weekly patterns
      if (type == 'weekly' && patternData['weekdays'] != null) {
        final List<dynamic> weekdays = patternData['weekdays'];
        if (weekdays.isNotEmpty) {
          // Convert weekday names to day numbers (1-7 where 1 is Monday)
          final Map<String, int> weekdayMap = {
            'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7
          };
          
          // Get day numbers from weekday strings
          final List<int> selectedDays = weekdays
              .map((day) => weekdayMap[day.toString()] ?? 0)
              .where((day) => day > 0)
              .toList();
          
          if (selectedDays.isNotEmpty) {
            // Get current day of week (1-7)
            final int startDayOfWeek = event.startTime.weekday;
            
            // Find the next selected day
            int daysToAdd = 0;
            bool foundDay = false;
            
            // Check if current day is selected
            if (selectedDays.contains(startDayOfWeek)) {
              foundDay = true;
            } else {
              // Find the next closest selected day
              for (int i = 1; i <= 7; i++) {
                final int checkDay = (startDayOfWeek + i) > 7 ? 
                    (startDayOfWeek + i) - 7 : (startDayOfWeek + i);
                
                if (selectedDays.contains(checkDay)) {
                  daysToAdd = i;
                  foundDay = true;
                  break;
                }
              }
            }
            
            // Calculate first occurrence date
            if (foundDay && daysToAdd > 0) {
              result['firstOccurrence'] = event.startTime.add(Duration(days: daysToAdd));
            }
          }
        }
      }
      
      switch (type) {
        case 'daily':
          result['icon'] = Icons.calendar_view_day;
          result['label'] = 'Daily';
          result['color'] = Colors.blue;
          break;
        case 'weekly':
          result['icon'] = Icons.calendar_view_week;
          result['label'] = 'Weekly';
          result['color'] = Colors.green;
          break;
        case 'monthly':
          result['icon'] = Icons.calendar_view_month;
          result['label'] = 'Monthly';
          result['color'] = Colors.purple;
          break;
        default:
          result['icon'] = Icons.repeat;
          result['label'] = 'Recurring';
          result['color'] = Colors.orange;
      }
      
      return result;
    } catch (e) {
      return {
        'hasPattern': false,
        'icon': Icons.calendar_today,
        'label': '',
        'color': Colors.grey,
      };
    }
  }

  String _getTimeUntilEvent(DateTime eventDate) {
    final now = DateTime.now();
    final difference = eventDate.difference(now);

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
    
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: isGridView ? 0 : 12, 
        vertical: isGridView ? 0 : 8
      ),
      clipBehavior: Clip.antiAlias,
      elevation: 0, // Removing elevation for a cleaner look
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16)
      ),
      child: InkWell(
        onTap: onTap ?? () => context.go('/events/${event.id}'),
        borderRadius: BorderRadius.circular(16),
        child: isGridView ? _buildGridItem(theme) : _buildListItem(theme),
      ),
    );
  }
  
  Widget _buildGridItem(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event image with price badge
        Stack(
          children: [
            Hero(
              tag: 'event_image_${event.id}_grid',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: event.mediaUrls?.isNotEmpty ?? false
                    ? Image.network(
                        event.mediaUrls!.first,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildGridPlaceholder(theme);
                        },
                      )
                    : _buildGridPlaceholder(theme),
              ),
            ),
            // Top-right badges
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      event.eventType == EventType.free ? 'FREE' : '₹${event.ticketPrice?.toStringAsFixed(0) ?? '0'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Builder(builder: (context) {
                      // Check if we need to use a different date for recurring events
                      DateTime dateToUse = event.startTime;
                      
                      // If this is a recurring event, use the calculated first occurrence date
                      if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty) {
                        final patternInfo = _getRecurringPatternInfo(event.recurringPattern!);
                        if (patternInfo['hasPattern'] && patternInfo.containsKey('firstOccurrence')) {
                          dateToUse = patternInfo['firstOccurrence'];
                        }
                      }
                      
                      return Text(
                        _getTimeUntilEvent(dateToUse),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // Content area
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title with maxLines for grid
              Text(
                event.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 6),
              
              // Category chip
              if (event.category != null)
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
                      Text(
                        event.category!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 8),
              
              // Description (shorter for grid)
              if (event.description != null)
                Text(
                  event.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              
              const SizedBox(height: 12),
              
              // Event details in compact format - Check for recurring pattern
              Builder(builder: (context) {
                // Check if we have a recurring pattern
                if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty) {
                  final patternInfo = _getRecurringPatternInfo(event.recurringPattern!);
                  if (patternInfo['hasPattern']) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: patternInfo['color'].withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: patternInfo['color'].withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            patternInfo['icon'],
                            size: 12,
                            color: patternInfo['color'],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            patternInfo['label'],
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: patternInfo['color'],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'from ${DateFormat('E, MMM d').format(patternInfo['firstOccurrence'])}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 9,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                }
                
                // Default date display if no recurring pattern
                return Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatDateTime(event.startTime),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                );
              }),
              
              if (event.location != null) ...[                        
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 12,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildListItem(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Hero(
              tag: 'event_image_${event.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: event.mediaUrls?.isNotEmpty ?? false
                    ? Image.network(
                        event.mediaUrls!.first,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder(theme);
                        },
                      )
                    : _buildPlaceholder(theme),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      event.eventType == EventType.free ? 'FREE' : '₹${event.ticketPrice?.toStringAsFixed(2) ?? '0.00'}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      // Use the appropriate date for status color calculations
                      color: _getStatusPillColor(
                        event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                            ? _getRecurringPatternInfo(event.recurringPattern!)['firstOccurrence']
                            : event.startTime,
                        event.status
                      ).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      // Use the first occurrence date for time remaining calculation
                      _getTimeUntilEvent(
                        event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                            ? _getRecurringPatternInfo(event.recurringPattern!)['firstOccurrence']
                            : event.startTime
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (event.category != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(event.category!),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: _getCategoryColor(event.category!).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getCategoryIcon(event.category!),
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  event.category!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
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
              if (event.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  event.description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Use appropriate icon for calendar based on whether event is recurring
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                              ? _getRecurringPatternInfo(event.recurringPattern!)['icon']
                              : Icons.calendar_today,
                            size: 16,
                            color: event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                              ? _getRecurringPatternInfo(event.recurringPattern!)['color']
                              : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Show 'Recurring Event' or 'Date & Time' based on pattern
                              Text(
                                event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                  ? 'Recurring Event'
                                  : 'Date & Time',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: event.recurringPattern != null && event.recurringPattern!.isNotEmpty
                                    ? _getRecurringPatternInfo(event.recurringPattern!)['color']
                                    : theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Show pattern label + date or just the formatted date
                              if (event.recurringPattern != null && event.recurringPattern!.isNotEmpty) ...[                                
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: _getRecurringPatternInfo(event.recurringPattern!)['color'].withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _getRecurringPatternInfo(event.recurringPattern!)['label'],
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: _getRecurringPatternInfo(event.recurringPattern!)['color'],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        _formatDateTime(_getRecurringPatternInfo(event.recurringPattern!)['firstOccurrence']),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[                              
                                Text(
                                  _formatDateTime(event.startTime),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (event.location != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.location_on,
                              size: 16,
                              color: theme.colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Location',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.secondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  event.location!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (event.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: event.tags.map((tag) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          '#$tag',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ),
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

  Color _getStatusPillColor(DateTime eventDate, EventStatus status) {
    // Check if event has ended first, regardless of status
    final now = DateTime.now();
    if (eventDate.isBefore(now)) {
      return Colors.red; // Show red for any ended event
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
