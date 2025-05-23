import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:scompass_07/core/utils/responsive_layout.dart';
import 'dart:convert';

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
    try {
      if (recurringPattern == null || recurringPattern!.isEmpty) {
        return startTime;
      }
      
      final patternData = json.decode(recurringPattern!);
      final type = patternData['type'] as String? ?? 'none';
      
      if (type == 'none') {
        return startTime;
      }
      
      // Special handling for weekly patterns
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
            final int startDayOfWeek = startTime.weekday;
            
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
              return startTime.add(Duration(days: daysToAdd));
            }
          }
        }
      }
      
      // For all other pattern types, use the start time
      return startTime;
    } catch (e) {
      debugPrint('Error calculating first occurrence: $e');
      return startTime;
    }
  }
  
  // Helper method to display recurring pattern information
  Widget _buildRecurringPatternInfo(BuildContext context, ThemeData theme) {
    try {
      if (recurringPattern == null || recurringPattern!.isEmpty) {
        return const SizedBox.shrink();
      }
      
      // Parse the recurring pattern JSON
      final patternData = json.decode(recurringPattern!);
      final type = patternData['type'] as String? ?? 'none';
      
      if (type == 'none') {
        return const SizedBox.shrink();
      }
      
      // Build pattern description based on type
      String patternDescription = '';
      String patternShortLabel = ''; // For badges/chips
      IconData patternIcon;
      Color patternColor = theme.colorScheme.primary;
      
      // Define color and content based on pattern type
      switch (type) {
        case 'daily':
          patternDescription = 'Repeats daily';
          patternShortLabel = 'Daily';
          patternIcon = Icons.calendar_view_day;
          patternColor = Colors.blue;
          break;
        case 'weekly':
          final weekdays = patternData['weekdays'] as List?;
          if (weekdays != null && weekdays.isNotEmpty) {
            patternDescription = 'Repeats weekly on ${weekdays.join(', ')}';
            if (weekdays.length <= 2) {
              patternShortLabel = weekdays.join(', ');
            } else {
              patternShortLabel = 'Weekly';
            }
          } else {
            patternDescription = 'Repeats weekly';
            patternShortLabel = 'Weekly';
          }
          patternIcon = Icons.calendar_view_week;
          patternColor = Colors.green;
          break;
        case 'monthly':
          final dayOfMonth = patternData['dayOfMonth'] as int? ?? startTime.day;
          patternDescription = 'Repeats monthly on day $dayOfMonth';
          patternShortLabel = 'Monthly';
          patternIcon = Icons.calendar_view_month;
          patternColor = Colors.purple;
          break;
        case 'custom':
          patternDescription = 'Custom recurring pattern';
          patternShortLabel = 'Custom';
          patternIcon = Icons.calendar_today;
          patternColor = Colors.orange;
          break;
        default:
          patternDescription = 'Recurring event';
          patternShortLabel = 'Recurring';
          patternIcon = Icons.repeat;
          patternColor = theme.colorScheme.primary;
      }
      
      // Add end condition info
      String endInfo = '';
      if (patternData.containsKey('endDate')) {
        final endDate = DateTime.parse(patternData['endDate']);
        endInfo = 'until ${DateFormat('MMM d, y').format(endDate)}';
      } else if (patternData.containsKey('occurrences')) {
        final occurrences = patternData['occurrences'];
        endInfo = '$occurrences occurrences';
      }
      
      // Return a more visually striking widget
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pattern type chip/badge
          Row(
            children: [
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
                      patternShortLabel,
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
          
          const SizedBox(height: 12),
          
          // Full pattern description
          Text(
            patternDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        ],
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
