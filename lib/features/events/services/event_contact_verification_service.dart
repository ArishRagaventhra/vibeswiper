import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/event_organizer_contact_provider.dart';
import '../repositories/event_organizer_contact_repository.dart';
import '../repositories/event_repository.dart';

class EventContactVerificationService {
  final EventOrganizerContactRepository _contactRepository;
  final EventRepository _eventRepository;
  Timer? _verificationTimer;

  EventContactVerificationService(
    this._contactRepository,
    this._eventRepository,
  );

  void startVerificationCheck() {
    // Check every hour for unverified contacts past deadline
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _checkUnverifiedContacts(),
    );
  }

  void stopVerificationCheck() {
    _verificationTimer?.cancel();
    _verificationTimer = null;
  }

  Future<void> _checkUnverifiedContacts() async {
    try {
      final unverifiedContacts = await _contactRepository.getUnverifiedContacts();
      
      for (final contact in unverifiedContacts) {
        if (contact.verificationDeadline != null &&
            contact.verificationDeadline!.isBefore(DateTime.now())) {
          // Delete the event if verification deadline has passed
          await _eventRepository.deleteEvent(contact.eventId);
        }
      }
    } catch (e) {
      print('Error checking unverified contacts: $e');
    }
  }

  Future<void> markContactAsVerified(String contactId) async {
    await _contactRepository.markAsVerified(contactId);
  }
}

final eventContactVerificationServiceProvider = Provider((ref) {
  final contactRepository = ref.watch(eventOrganizerContactRepositoryProvider);
  final eventRepository = ref.watch(eventRepositoryProvider);
  
  return EventContactVerificationService(
    contactRepository,
    eventRepository,
  );
});
