import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../controllers/event_controller.dart';
import '../models/event_model.dart';
import '../repositories/event_participant_repository.dart';
import '../repositories/event_organizer_contact_repository.dart';
import '../repositories/event_requirements_repository.dart';
import '../providers/event_organizer_contact_provider.dart';
import '../../payments/providers/payment_provider.dart';
import '../../payments/services/event_payment_service.dart';

final eventCreationServiceProvider = Provider((ref) => EventCreationService(ref));

// Provider to store pending event data (temporary storage for events awaiting payment)
final pendingEventDataProvider = StateProvider<Map<String, Map<String, dynamic>>>((ref) => {});

class EventCreationService {
  final Ref _ref;

  EventCreationService(this._ref);

  Future<Event?> createEvent({
    required String title,
    required String creatorId,
    String? description,
    required String location,
    required String city,
    required String country,
    required DateTime startTime,
    required DateTime endTime,
    required EventType eventType,
    required EventVisibility visibility,
    int? maxParticipants,
    String? category,
    List<String>? tags,
    String? recurringPattern,
    Duration? reminderBefore,
    DateTime? registrationDeadline,
    double? ticketPrice,
    double? vibePrice,
    String? currency,
    List<XFile>? mediaFiles,
    String? accessCode,
    required String organizerName,
    required String organizerEmail,
    required String organizerPhone,
    Map<String, dynamic>? requirementsData,
    BuildContext? context,
  }) async {
    Event? draftEvent;
    
    try {
      // Validate location data
      if (location.isEmpty || city.isEmpty || country.isEmpty) {
        throw Exception('Location details are required');
      }

      // Validate prices for paid events
      if (eventType == EventType.paid) {
        if (ticketPrice == null || ticketPrice <= 0) {
          throw Exception('Valid ticket price is required for paid events');
        }
        if (vibePrice == null || vibePrice <= 0) {
          throw Exception('Valid Vibe price is required for paid events');
        }
        if (vibePrice > ticketPrice) {
          throw Exception('Vibe price cannot be higher than ticket price');
        }
        
        // IMPORTANT: For paid events, handle payment FIRST before creating the event
        final paymentSuccess = await _processPaymentFirst(
          eventName: title,
          userEmail: organizerEmail,
          userContact: organizerPhone,
          title: title,
          creatorId: creatorId,
          description: description,
          location: location,
          city: city,
          country: country,
          startTime: startTime,
          endTime: endTime,
          eventType: eventType,
          visibility: visibility,
          maxParticipants: maxParticipants,
          category: category,
          tags: tags,
          recurringPattern: recurringPattern,
          reminderBefore: reminderBefore,
          registrationDeadline: registrationDeadline,
          ticketPrice: ticketPrice,
          vibePrice: vibePrice,
          currency: currency,
          mediaFiles: mediaFiles,
          accessCode: accessCode,
          organizerName: organizerName,
          requirementsData: requirementsData,
          context: context,
        );
        
        // Only proceed with event creation if payment was successful
        if (!paymentSuccess) {
          debugPrint('Payment was not successful - aborting event creation');
          return null;
        }
      }

      // Only create event after successful payment (or for free events)
      draftEvent = await _ref.read(eventControllerProvider.notifier).createEventWithMedia(
            title: title,
            creatorId: creatorId,
            description: description,
            location: '$location, $city, $country',
            startTime: startTime,
            endTime: endTime,
            eventType: eventType,
            visibility: visibility,
            maxParticipants: maxParticipants,
            category: category,
            tags: tags,
            recurringPattern: recurringPattern,
            reminderBefore: reminderBefore,
            registrationDeadline: registrationDeadline,
            ticketPrice: ticketPrice,
            vibePrice: vibePrice,
            currency: currency,
            mediaFiles: mediaFiles ?? [],
            accessCode: accessCode,
          );

      if (draftEvent != null) {
        try {
          // 2. Store organizer contact details
          final contactRepo = _ref.read(eventOrganizerContactRepositoryProvider);
          await contactRepo.createContact(
            eventId: draftEvent.id,
            name: organizerName,
            email: organizerEmail,
            phone: organizerPhone,
          );

          // Add creator as organizer participant
          final participantRepo = _ref.read(eventParticipantRepositoryProvider);
          await participantRepo.joinEvent(draftEvent.id, creatorId);
          
          // 3. Store event requirements if provided
          if (requirementsData != null) {
            final requirementsRepo = _ref.read(eventRequirementsRepositoryProvider);
            await requirementsRepo.createEventRequirements(draftEvent.id, requirementsData);
          }

          // Event created successfully - for paid events, it's already finalized
          // For free events, finalize it now
          if (eventType != EventType.paid) {
            await finalizeEventCreation(draftEvent.id);
          }
          
          return draftEvent;
        } catch (e) {
          // If something fails after event creation, delete the event
          if (draftEvent != null) {
            await _ref.read(eventControllerProvider.notifier).deleteEvent(
              draftEvent.id,
              creatorId,
            );
          }
          throw Exception('Failed to complete event creation: $e');
        }
      }
      return null;
    } catch (e) {
      // Clean up if anything fails
      if (draftEvent != null) {
        await _ref.read(eventControllerProvider.notifier).deleteEvent(
          draftEvent.id,
          creatorId,
        );
      }
      debugPrint('Error creating event: $e');
      rethrow;
    }
  }
  
  // New method to process payment before creating the event
  Future<bool> _processPaymentFirst({
    required String eventName,
    required String userEmail,
    required String userContact,
    required String title,
    required String creatorId,
    String? description,
    required String location,
    required String city,
    required String country,
    required DateTime startTime,
    required DateTime endTime,
    required EventType eventType,
    required EventVisibility visibility,
    int? maxParticipants,
    String? category,
    List<String>? tags,
    String? recurringPattern,
    Duration? reminderBefore,
    DateTime? registrationDeadline,
    double? ticketPrice,
    double? vibePrice,
    String? currency,
    List<XFile>? mediaFiles,
    String? accessCode,
    required String organizerName,
    Map<String, dynamic>? requirementsData,
    BuildContext? context,
  }) async {
    debugPrint('Processing payment before creating event');
    
    try {
      final paymentService = _ref.read(eventPaymentServiceProvider);
      final completer = Completer<bool>();
      
      // Create a temporary ID to track this payment
      final tempEventId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      
      // Set up a listener for payment status
      final paymentNotifier = _ref.read(paymentProvider.notifier);
      bool paymentHandled = false;
      Timer? timeoutTimer;
      
      // Store all event data with the temporary ID
      // This allows us to create the event later if payment succeeds after auto-cancellation
      final eventData = {
        'title': title,
        'creatorId': creatorId,
        'description': description,
        'location': location,
        'city': city,
        'country': country,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'eventType': eventType.toString(),
        'visibility': visibility.toString(),
        'maxParticipants': maxParticipants,
        'category': category,
        'tags': tags,
        'recurringPattern': recurringPattern,
        'reminderBefore': reminderBefore?.inSeconds,
        'registrationDeadline': registrationDeadline?.toIso8601String(),
        'ticketPrice': ticketPrice,
        'vibePrice': vibePrice,
        'currency': currency,
        'mediaFiles': mediaFiles?.map((file) => file.path).toList(),
        'accessCode': accessCode,
        'organizerName': organizerName,
        'organizerEmail': userEmail,
        'organizerPhone': userContact,
        'requirementsData': requirementsData,
      };
      
      // Store event data
      _ref.read(pendingEventDataProvider.notifier).update((state) => {
        ...state,
        tempEventId: eventData,
      });
      
      // Set up a timeout - payment must complete within 5 minutes
      timeoutTimer = Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted && !paymentHandled) {
          debugPrint('Payment timeout - aborting event creation');
          paymentHandled = true;
          completer.complete(false);
        }
      });
      
      // Start the payment
      await paymentService.initiateEventCreationPayment(
        eventId: tempEventId,
        eventName: eventName,
        userEmail: userEmail,
        userContact: userContact,
        context: context,
      );
      
      // Set up a listener for payment status updates
      final subscription = _ref.listen(paymentProvider, (prev, next) {
        next.whenData((payments) {
          // Look for payments matching our temporary ID
          for (final payment in payments) {
            if (payment.eventId == tempEventId && !paymentHandled) {
              debugPrint('Payment status updated: ${payment.status}');
              
              if (payment.isSuccessful) {
                debugPrint('Payment successful! Proceeding with event creation');
                paymentHandled = true;
                timeoutTimer?.cancel();
                completer.complete(true);
              } else if (payment.isFailed || payment.status == 'cancelled') {
                debugPrint('Payment failed or cancelled - aborting event creation');
                paymentHandled = true;
                timeoutTimer?.cancel();
                completer.complete(false);
              }
              // If pending, continue waiting
            }
          }
        });
      });
      
      // Wait for payment completion
      final result = await completer.future;
      
      // Clean up
      subscription.close();
      timeoutTimer?.cancel();
      
      return result;
    } catch (e) {
      debugPrint('Error processing payment: $e');
      return false;
    }
  }

  // New method to create events from previously cancelled but now successful payments
  Future<Event?> createEventFromDelayedPayment(String tempEventId) async {
    final eventData = _ref.read(pendingEventDataProvider)[tempEventId];

    if (eventData != null) {
      try {
        // Need to handle the mediaFiles correctly - convert paths back to XFile objects
        List<XFile>? mediaFiles;
        if (eventData['mediaFiles'] != null) {
          mediaFiles = (eventData['mediaFiles'] as List<dynamic>).map((path) => XFile(path.toString())).toList();
        }
        
        // Parse enum values correctly
        final eventType = EventType.values.firstWhere(
          (e) => e.toString() == eventData['eventType'],
          orElse: () => EventType.free
        );
        
        final visibility = EventVisibility.values.firstWhere(
          (v) => v.toString() == eventData['visibility'],
          orElse: () => EventVisibility.public
        );
        
        // Parse dates
        final startTime = eventData['startTime'] != null ? 
          DateTime.tryParse(eventData['startTime']) ?? DateTime.now() : DateTime.now();
          
        final endTime = eventData['endTime'] != null ? 
          DateTime.tryParse(eventData['endTime']) ?? DateTime.now().add(Duration(hours: 1)) : 
          DateTime.now().add(Duration(hours: 1));
          
        final registrationDeadline = eventData['registrationDeadline'] != null ? 
          DateTime.tryParse(eventData['registrationDeadline']) : null;
        
        // Parse duration
        Duration? reminderBefore;
        if (eventData['reminderBefore'] != null) {
          reminderBefore = Duration(seconds: eventData['reminderBefore']);
        }
        
        // Handle tags
        List<String> tags = [];
        if (eventData['tags'] != null) {
          tags = (eventData['tags'] as List<dynamic>).map((tag) => tag.toString()).toList();
        }

        final draftEvent = await _ref.read(eventControllerProvider.notifier).createEventWithMedia(
          title: eventData['title'] ?? 'Event',
          creatorId: eventData['creatorId'] ?? '',
          description: eventData['description'],
          location: '${eventData['location'] ?? ''}, ${eventData['city'] ?? ''}, ${eventData['country'] ?? ''}',
          startTime: startTime,
          endTime: endTime,
          eventType: eventType,
          visibility: visibility,
          maxParticipants: eventData['maxParticipants'],
          category: eventData['category'],
          tags: tags,
          recurringPattern: eventData['recurringPattern'],
          reminderBefore: reminderBefore,
          registrationDeadline: registrationDeadline,
          ticketPrice: eventData['ticketPrice'],
          vibePrice: eventData['vibePrice'],
          currency: eventData['currency'],
          mediaFiles: mediaFiles ?? [],
          accessCode: eventData['accessCode'],
        );

        if (draftEvent != null) {
          try {
            // 2. Store organizer contact details
            final contactRepo = _ref.read(eventOrganizerContactRepositoryProvider);
            await contactRepo.createContact(
              eventId: draftEvent.id,
              name: eventData['organizerName'] ?? '',
              email: eventData['organizerEmail'] ?? '',
              phone: eventData['organizerPhone'] ?? '',
            );

            // Add creator as organizer participant
            final participantRepo = _ref.read(eventParticipantRepositoryProvider);
            await participantRepo.joinEvent(draftEvent.id, eventData['creatorId'] ?? '');

            // 3. Store event requirements if provided
            if (eventData['requirementsData'] != null) {
              final requirementsRepo = _ref.read(eventRequirementsRepositoryProvider);
              await requirementsRepo.createEventRequirements(draftEvent.id, eventData['requirementsData']);
            }

            // Event created successfully - finalize it since this is from a successful payment
            await finalizeEventCreation(draftEvent.id);

            return draftEvent;
          } catch (e) {
            // If something fails after event creation, delete the event
            if (draftEvent != null) {
              await _ref.read(eventControllerProvider.notifier).deleteEvent(
                draftEvent.id,
                eventData['creatorId'] ?? '',
              );
            }
            throw Exception('Failed to complete event creation: $e');
          }
        }
        return null;
      } catch (e) {
        // Clean up if anything fails
        debugPrint('Error creating event from delayed payment: $e');
        rethrow;
      }
    }
    return null;
  }

  // This will be called by PaymentNotifier after successful payment
  Future<void> finalizeEventCreation(String eventId) async {
    try {
      debugPrint('Finalizing event $eventId - ONLY updating status, NOT creating chat rooms');
      final supabase = _ref.read(supabaseClientProvider);
      
      // ONLY update event status - do NOT create any chat rooms here
      await supabase
          .from('events')
          .update({
            'status': EventStatus.upcoming.toString().split('.').last,
            'is_platform_fee_paid': true,
          })
          .eq('id', eventId);

      // Refresh the events list
      await _ref.read(eventControllerProvider.notifier).loadEvents();
    } catch (e) {
      debugPrint('Error finalizing event: $e');
      rethrow;
    }
  }
}
