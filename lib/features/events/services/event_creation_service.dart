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
    String? currency,
    List<XFile>? mediaFiles,
    String? accessCode,
    required String organizerName,
    required String organizerEmail,
    required String organizerPhone,
    Map<String, dynamic>? requirementsData,
  }) async {
    Event? draftEvent;
    
    try {
      // Validate location data
      if (location.isEmpty || city.isEmpty || country.isEmpty) {
        throw Exception('Location details are required');
      }

      // 1. Create draft event
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

          // 3. Handle payment if needed
          if (eventType == EventType.paid) {
            try {
              final paymentService = _ref.read(eventPaymentServiceProvider);
              await paymentService.initiateEventCreationPayment(
                eventId: draftEvent.id,
                eventName: draftEvent.title,
                userEmail: organizerEmail,
                userContact: organizerPhone,
              );
            } catch (e) {
              // If payment fails, delete the event and rethrow
              await _ref.read(eventControllerProvider.notifier).deleteEvent(
                draftEvent.id,
                creatorId,
              );
              throw Exception('Payment failed: $e');
            }
          }

          return draftEvent;
        } catch (e) {
          // If contact creation fails, delete the event and rethrow
          if (draftEvent != null) {
            await _ref.read(eventControllerProvider.notifier).deleteEvent(
              draftEvent.id,
              creatorId,
            );
          }
          throw Exception('Failed to save contact details: $e');
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
      print('Error creating event: $e');
      rethrow;
    }
  }

  // This will be called by PaymentNotifier after successful payment
  Future<void> finalizeEventCreation(String eventId) async {
    try {
      // Since there's no direct updateEventStatus method, we need to handle this differently
      // We could either:
      // 1. Add a new method to EventController for status updates
      // 2. Use the Supabase client directly
      // For now, we'll use Supabase client directly
      
      final supabase = _ref.read(supabaseClientProvider);
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
      rethrow;
    }
  }
}
