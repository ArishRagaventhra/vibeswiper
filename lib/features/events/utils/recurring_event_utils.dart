import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/event_model.dart';

/// Utility class for handling recurring event patterns
class RecurringEventUtils {
  /// Calculate the next occurrence date for a recurring event
  /// Takes into account the event's recurring pattern and ensures the returned date is in the future
  static DateTime calculateNextOccurrence(Event event, {DateTime? fromDate}) {
    final now = fromDate ?? DateTime.now();
    
    // If no recurring pattern or invalid pattern, return the original date
    if (event.recurringPattern == null || event.recurringPattern!.isEmpty) {
      return event.startTime;
    }
    
    try {
      final patternData = json.decode(event.recurringPattern!);
      final type = patternData['type'] as String? ?? 'none';
      
      if (type == 'none') return event.startTime;
      
      // Calculate event duration (to maintain same duration for each occurrence)
      final duration = event.endTime.difference(event.startTime);
      
      // Start with the original start date as our reference point
      DateTime referenceDate = event.startTime;
      DateTime nextOccurrence = referenceDate;
      
      // For daily patterns
      if (type == 'daily') {
        // Find the next occurrence after now
        while (nextOccurrence.isBefore(now)) {
          nextOccurrence = nextOccurrence.add(const Duration(days: 1));
        }
      }
      
      // For weekly patterns
      else if (type == 'weekly' && patternData['weekdays'] != null) {
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
            // Sort the selected days
            selectedDays.sort();
            
            // Keep incrementing by days until we find the next occurrence after now
            bool foundNextDay = false;
            
            // If the original date is already in the future, check if it's on a valid day
            if (referenceDate.isAfter(now) && 
                selectedDays.contains(referenceDate.weekday)) {
              return referenceDate;
            }
            
            // Otherwise, find the next valid day after now
            while (!foundNextDay) {
              // Check if current day is in selected days
              if (selectedDays.contains(nextOccurrence.weekday) && 
                  nextOccurrence.isAfter(now)) {
                foundNextDay = true;
              } else {
                // Move to the next day
                nextOccurrence = nextOccurrence.add(const Duration(days: 1));
              }
              
              // Safety check to prevent infinite loop - limit to 100 iterations
              // This would allow checking up to 14 weeks ahead
              if (nextOccurrence.difference(referenceDate).inDays > 100) {
                return event.startTime; // Fallback to original date
              }
            }
          }
        }
      }
      
      // For monthly patterns
      else if (type == 'monthly') {
        final dayOfMonth = event.startTime.day;
        
        // Start with original date
        nextOccurrence = referenceDate;
        
        // Keep incrementing months until we find one in the future
        while (nextOccurrence.isBefore(now)) {
          // Move to the same day of the next month
          final nextMonth = nextOccurrence.month + 1;
          final nextYear = nextOccurrence.year + (nextMonth > 12 ? 1 : 0);
          final normalizedMonth = nextMonth > 12 ? nextMonth - 12 : nextMonth;
          
          // Try to create a date with the same day in the next month
          try {
            nextOccurrence = DateTime(nextYear, normalizedMonth, dayOfMonth, 
                nextOccurrence.hour, nextOccurrence.minute);
          } catch (e) {
            // Handle invalid dates (e.g. Feb 30) by using the last day of month
            final lastDayOfMonth = DateTime(nextYear, normalizedMonth + 1, 0).day;
            nextOccurrence = DateTime(nextYear, normalizedMonth, lastDayOfMonth,
                nextOccurrence.hour, nextOccurrence.minute);
          }
        }
      }
      
      // Check for until date if provided in pattern
      if (patternData['until'] != null) {
        final untilDate = DateTime.parse(patternData['until']);
        if (nextOccurrence.isAfter(untilDate)) {
          // If next occurrence is after the until date, the event series has ended
          return event.startTime; // Return original date to indicate series is over
        }
      }
      
      // Check for occurrence count if provided
      if (patternData['count'] != null) {
        final count = patternData['count'] as int;
        int occurrences = 0;
        
        DateTime checkDate = referenceDate;
        
        // Count occurrences up to our calculated next date
        while (checkDate.isBefore(nextOccurrence) || checkDate.isAtSameMomentAs(nextOccurrence)) {
          if (type == 'daily') {
            occurrences++;
            checkDate = checkDate.add(const Duration(days: 1));
          } else if (type == 'weekly' && patternData['weekdays'] != null) {
            final List<dynamic> weekdays = patternData['weekdays'];
            final Map<String, int> weekdayMap = {
              'Mon': 1, 'Tue': 2, 'Wed': 3, 'Thu': 4, 'Fri': 5, 'Sat': 6, 'Sun': 7
            };
            final List<int> selectedDays = weekdays
                .map((day) => weekdayMap[day.toString()] ?? 0)
                .where((day) => day > 0)
                .toList();
                
            if (selectedDays.contains(checkDate.weekday)) {
              occurrences++;
            }
            
            checkDate = checkDate.add(const Duration(days: 1));
          } else if (type == 'monthly') {
            occurrences++;
            
            // Move to the same day of the next month
            final nextMonth = checkDate.month + 1;
            final nextYear = checkDate.year + (nextMonth > 12 ? 1 : 0);
            final normalizedMonth = nextMonth > 12 ? nextMonth - 12 : nextMonth;
            
            try {
              checkDate = DateTime(nextYear, normalizedMonth, checkDate.day);
            } catch (e) {
              // Handle invalid dates (e.g. Feb 30)
              final lastDayOfMonth = DateTime(nextYear, normalizedMonth + 1, 0).day;
              checkDate = DateTime(nextYear, normalizedMonth, lastDayOfMonth);
            }
          }
          
          // Safety check to prevent infinite loop
          if (checkDate.difference(referenceDate).inDays > 1000) {
            break;
          }
        }
        
        if (occurrences > count) {
          // We've exceeded the number of occurrences, so the event series has ended
          return event.startTime; // Return original date to indicate series is over
        }
      }
      
      // Calculate the corresponding end time by adding the original duration
      final adjustedEndTime = nextOccurrence.add(duration);
      
      // Return a copy of the event with updated dates
      return nextOccurrence;
    } catch (e) {
      debugPrint('Error calculating next occurrence: $e');
      return event.startTime; // Fallback to original date
    }
  }

  /// Determines if an event is truly completed (all occurrences have passed)
  static bool isEventSeriesCompleted(Event event) {
    if (event.recurringPattern == null || event.recurringPattern!.isEmpty) {
      // Non-recurring events use normal completion logic
      return DateTime.now().isAfter(event.endTime);
    }
    
    try {
      final patternData = json.decode(event.recurringPattern!);
      
      // Check for until date
      if (patternData['until'] != null) {
        final untilDate = DateTime.parse(patternData['until']);
        return DateTime.now().isAfter(untilDate);
      }
      
      // If we can calculate a next occurrence date that's in the future, 
      // the event series is not completed
      final nextOccurrence = calculateNextOccurrence(event);
      
      // If next occurrence is the same as the original start time and 
      // the original start time is in the past, then the series is completed
      if (nextOccurrence.isAtSameMomentAs(event.startTime) && 
          DateTime.now().isAfter(event.startTime)) {
        return true;
      }
      
      // Otherwise, check if the next occurrence is in the future
      return DateTime.now().isAfter(nextOccurrence);
    } catch (e) {
      debugPrint('Error checking event series completion: $e');
      return DateTime.now().isAfter(event.endTime);
    }
  }
  
  /// Gets the display information for the next occurrence
  static Map<String, dynamic> getNextOccurrenceInfo(Event event) {
    final Map<String, dynamic> result = {
      'hasPattern': false,
      'icon': Icons.calendar_today,
      'label': '',
      'color': Colors.grey,
      'nextOccurrence': event.startTime,
      'nextEndTime': event.endTime,
      'isCompleted': DateTime.now().isAfter(event.endTime),
    };
    
    if (event.recurringPattern == null || event.recurringPattern!.isEmpty) {
      return result;
    }
    
    try {
      final patternData = json.decode(event.recurringPattern!);
      final type = patternData['type'] as String? ?? 'none';
      
      if (type == 'none') return result;
      
      result['hasPattern'] = true;
      
      // Calculate the next occurrence
      final nextOccurrence = calculateNextOccurrence(event);
      
      // Calculate if the series is completed
      final isCompleted = isEventSeriesCompleted(event);
      
      // Calculate the duration to maintain the same event length
      final duration = event.endTime.difference(event.startTime);
      
      // Set the next occurrence info
      result['nextOccurrence'] = nextOccurrence;
      result['nextEndTime'] = nextOccurrence.add(duration);
      result['isCompleted'] = isCompleted;
      
      // Set pattern-specific info
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
      debugPrint('Error getting next occurrence info: $e');
      return result;
    }
  }
}
