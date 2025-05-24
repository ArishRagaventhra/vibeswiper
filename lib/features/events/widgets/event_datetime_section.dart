import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scompass_07/core/utils/responsive_layout.dart';
import 'dart:convert';
import '../utils/recurring_event_utils.dart';
import '../models/event_model.dart';

class EventDateTimeSection extends StatelessWidget {
  final DateTime startTime;
  final DateTime endTime;
  final Function() onAddToCalendar;
  final String? recurringPattern;

  const EventDateTimeSection({
    Key? key,
    required this.startTime,
    required this.endTime,
    required this.onAddToCalendar,
    this.recurringPattern,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    // Check if we have a valid recurring pattern
    bool hasValidRecurringPattern = false;
    String patternType = 'none';
    
    if (recurringPattern != null && recurringPattern!.isNotEmpty) {
      try {
        final patternData = json.decode(recurringPattern!);
        patternType = patternData['type'] as String? ?? 'none';
        hasValidRecurringPattern = patternType != 'none';
      } catch (e) {
        // Handle parsing error
        hasValidRecurringPattern = false;
      }
    }
    
    // Choose the appropriate icon based on pattern
    IconData calendarIcon = Icons.calendar_today_outlined;
    if (hasValidRecurringPattern) {
      switch (patternType) {
        case 'daily':
          calendarIcon = Icons.calendar_view_day;
          break;
        case 'weekly':
          calendarIcon = Icons.calendar_view_week;
          break;
        case 'monthly':
          calendarIcon = Icons.calendar_view_month;
          break;
        default:
          calendarIcon = Icons.repeat;
      }
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Rounded container for icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        calendarIcon,
                        color: hasValidRecurringPattern
                            ? theme.colorScheme.primary
                            : (theme.brightness == Brightness.dark
                                ? Colors.white70
                                : Colors.black87),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    hasValidRecurringPattern ? 'Recurring Event' : 'Date & Time',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: hasValidRecurringPattern ? theme.colorScheme.primary : null,
                    ),
                  ),
                ],
              ),
              
              // Add to Calendar Button - Responsive design
              _buildAddToCalendarButton(context, theme, size)
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Show either recurring pattern or date/time details
          if (hasValidRecurringPattern) ...[  // Use spread operator with a list
            // Recurring pattern as the primary content
            _buildRecurringPatternInfo(context, theme)
          ] else ...[  // Use spread operator with a list
            // Standard date and time details as fallback
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMM d, y').format(startTime),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('h:mm a').format(startTime)} - ${DateFormat('h:mm a').format(endTime)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          
          // If it's a recurring event, show the first occurrence date in smaller text
          if (hasValidRecurringPattern) ...[  // Use spread operator with a list
            const SizedBox(height: 12),
            Text(
              'First occurrence:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<DateTime>(  // Using FutureBuilder to calculate the first occurrence
              future: _calculateFirstOccurrence(patternType),
              builder: (context, snapshot) {
                // Default to start time if calculation fails
                final firstOccurrence = snapshot.data ?? startTime;
                return Text(
                  DateFormat('E, MMM d, yyyy').format(firstOccurrence),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ]
        ],
      ),
    );
  }
  
  // Helper method to calculate the first occurrence date for recurring patterns
  Future<DateTime> _calculateFirstOccurrence(String patternType) async {
    // Create a temporary Event object to use with RecurringEventUtils
    final tempEvent = Event(
      id: 'temp',
      creatorId: 'temp',
      title: 'temp',
      startTime: startTime,
      endTime: endTime,
      eventType: EventType.free,
      visibility: EventVisibility.public,
      tags: [],
      status: EventStatus.upcoming,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      recurringPattern: recurringPattern,
    );
    
    // Use the utility class to calculate the next occurrence
    final nextOccurrence = RecurringEventUtils.calculateNextOccurrence(tempEvent);
    return nextOccurrence;
  }
  
  // Helper method to display recurring pattern information
  Widget _buildRecurringPatternInfo(BuildContext context, ThemeData theme) {
    try {
      // Create a temporary Event object to use with RecurringEventUtils
      final tempEvent = Event(
        id: 'temp',
        creatorId: 'temp',
        title: 'temp',
        startTime: startTime,
        endTime: endTime,
        eventType: EventType.free,
        visibility: EventVisibility.public,
        tags: [],
        status: EventStatus.upcoming,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        recurringPattern: recurringPattern,
      );
      
      // Get comprehensive recurring pattern info
      final patternInfo = RecurringEventUtils.getNextOccurrenceInfo(tempEvent);
      final bool hasPattern = patternInfo['hasPattern'] as bool? ?? false;
      
      if (!hasPattern) {
        return const SizedBox.shrink();
      }
      
      final patternData = json.decode(recurringPattern!);
      final type = patternData['type'] as String? ?? 'none';
      final untilDate = patternData['until'] != null ? DateTime.parse(patternData['until']) : null;
      final occurrenceCount = patternData['count'] as int?;
      
      // Extract information from pattern info
      final bool isCompleted = patternInfo['isCompleted'] as bool? ?? false;
      final DateTime nextOccurrence = patternInfo['nextOccurrence'] as DateTime? ?? startTime;
      final DateTime nextEndTime = patternInfo['nextEndTime'] as DateTime? ?? endTime;
      final IconData patternIcon = patternInfo['icon'] as IconData? ?? Icons.repeat;
      final String patternBadge = patternInfo['label'] as String? ?? 'Recurring';
      final Color patternColor = patternInfo['color'] as Color? ?? Colors.orange;
      
      // Format dates for display
      final nextOccurrenceDate = DateFormat('EEE, MMM d, y').format(nextOccurrence);
      final nextOccurrenceTime = DateFormat('h:mm a').format(nextOccurrence);
      final endTimeStr = DateFormat('h:mm a').format(nextEndTime);
      
      // Create pattern description
      String patternDescription = 'This event repeats ';
      String endInfo = '';
      
      // Determine pattern-specific information
      switch (type) {
        case 'daily':
          patternDescription += 'daily';
          break;
        case 'weekly':
          // Format weekday information if available
          if (patternData['weekdays'] != null) {
            final List<dynamic> weekdays = patternData['weekdays'];
            if (weekdays.isNotEmpty) {
              patternDescription += 'weekly on ';
              
              // Handle different weekday formats
              final List<String> formattedWeekdays = [];
              for (var day in weekdays) {
                switch (day.toString()) {
                  case 'Mon':
                    formattedWeekdays.add('Monday');
                    break;
                  case 'Tue':
                    formattedWeekdays.add('Tuesday');
                    break;
                  case 'Wed':
                    formattedWeekdays.add('Wednesday');
                    break;
                  case 'Thu':
                    formattedWeekdays.add('Thursday');
                    break;
                  case 'Fri':
                    formattedWeekdays.add('Friday');
                    break;
                  case 'Sat':
                    formattedWeekdays.add('Saturday');
                    break;
                  case 'Sun':
                    formattedWeekdays.add('Sunday');
                    break;
                  default:
                    formattedWeekdays.add(day.toString());
                }
              }
              
              if (formattedWeekdays.length == 1) {
                patternDescription += formattedWeekdays[0];
              } else if (formattedWeekdays.length == 2) {
                patternDescription += '${formattedWeekdays[0]} and ${formattedWeekdays[1]}';
              } else {
                final lastDay = formattedWeekdays.removeLast();
                patternDescription += '${formattedWeekdays.join(', ')}, and $lastDay';
              }
            } else {
              patternDescription += 'weekly';
            }
          } else {
            patternDescription += 'weekly';
          }
          break;
        case 'monthly':
          patternDescription += 'monthly on day ${startTime.day}';
          break;
        default:
          patternDescription += 'regularly';
      }
      
      // Add end condition information
      if (untilDate != null) {
        final formattedUntil = DateFormat('MMM d, y').format(untilDate);
        patternDescription += ' until $formattedUntil';
        endInfo = 'Until $formattedUntil';
      } else if (occurrenceCount != null) {
        patternDescription += ' for $occurrenceCount occurrences';
        endInfo = '$occurrenceCount occurrences';
      } else {
        patternDescription += ' indefinitely';
        endInfo = 'No end date';
      }
      
      // If the series is completed, show a different message
      if (isCompleted) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Pattern badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event_busy,
                          size: 16,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Series Ended',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'This recurring event series has ended.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Original schedule: $patternDescription',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      }
      
      // Normal display for active recurring events
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light 
              ? Colors.white 
              : theme.colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: theme.brightness == Brightness.light 
              ? Border.all(color: theme.colorScheme.outline.withOpacity(0.2)) 
              : null,
        ),
        child: Row(
          children: [
            // Pattern type chip/badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: patternColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: patternColor.withOpacity(0.5), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    patternIcon,
                    size: 16,
                    color: patternColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    patternBadge,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: patternColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (endInfo.isNotEmpty) ...[  
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  endInfo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    } catch (e) {
      // In case of any error parsing the pattern, show a simple fallback
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.repeat,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Recurring event',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }
  
  // Helper method to build a responsive Add to Calendar button
  Widget _buildAddToCalendarButton(BuildContext context, ThemeData theme, Size size) {
    final isSmallScreen = ResponsiveLayout.isMobile(context);
    final isVerySmallScreen = size.width < 360; // Extra check for very small screens
    
    // For very small screens, show only icon button
    if (isVerySmallScreen) {
      return IconButton(
        onPressed: onAddToCalendar,
        icon: Icon(
          Icons.add_circle_outline,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        tooltip: 'Add to Calendar',
        constraints: const BoxConstraints(), // Remove default padding
        padding: const EdgeInsets.all(8),
      );
    }
    
    // For small screens, use a compact button with smaller text and padding
    if (isSmallScreen) {
      return ElevatedButton.icon(
        onPressed: onAddToCalendar,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primaryContainer,
          foregroundColor: theme.colorScheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 32), // Smaller minimum height
          tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Tighter hit target
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(
          Icons.add,
          size: 14,
        ),
        label: Text(
          'Add',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }
    
    // For larger screens, use the original design
    return ElevatedButton.icon(
      onPressed: onAddToCalendar,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: const Icon(
        Icons.add,
        size: 16,
      ),
      label: const Text('Add to Calendar'),
    );
  }
}
