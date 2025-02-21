import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_organizer_contact_model.dart';
import '../repositories/event_organizer_contact_repository.dart';

final eventOrganizerContactRepositoryProvider = Provider((ref) {
  final supabase = Supabase.instance.client;
  return EventOrganizerContactRepository(supabase);
});

final eventContactProvider = FutureProvider.family<EventOrganizerContact?, String>((ref, eventId) async {
  final repository = ref.watch(eventOrganizerContactRepositoryProvider);
  return repository.getContactByEventId(eventId);
});

final unverifiedContactsStreamProvider = StreamProvider<List<EventOrganizerContact>>((ref) {
  final repository = ref.watch(eventOrganizerContactRepositoryProvider);
  return repository.watchUnverifiedContacts();
});
