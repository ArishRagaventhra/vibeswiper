import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_organizer_contact_model.dart';

class EventOrganizerContactRepository {
  final SupabaseClient _supabase;

  EventOrganizerContactRepository(this._supabase);

  Future<EventOrganizerContact> createContact({
    required String eventId,
    required String name,
    required String email,
    required String phone,
  }) async {
    final verificationDeadline = DateTime.now().add(const Duration(hours: 24));
    
    final response = await _supabase.from('event_organizer_contacts').insert({
      'event_id': eventId,
      'name': name,
      'email': email,
      'phone': phone,
      'verification_deadline': verificationDeadline.toIso8601String(),
    }).select().single();

    return EventOrganizerContact.fromJson(response);
  }

  Future<EventOrganizerContact?> getContactByEventId(String eventId) async {
    final response = await _supabase
        .from('event_organizer_contacts')
        .select()
        .eq('event_id', eventId)
        .single();

    if (response == null) return null;
    return EventOrganizerContact.fromJson(response);
  }

  Future<void> markAsVerified(String contactId) async {
    await _supabase.from('event_organizer_contacts').update({
      'contact_verified': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', contactId);
  }

  Future<void> updateContact({
    required String contactId,
    String? name,
    String? email,
    String? phone,
  }) async {
    final updates = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _supabase
        .from('event_organizer_contacts')
        .update(updates)
        .eq('id', contactId);
  }

  Future<List<EventOrganizerContact>> getUnverifiedContacts() async {
    final response = await _supabase
        .from('event_organizer_contacts')
        .select()
        .eq('contact_verified', false)
        .lte('verification_deadline', DateTime.now().toIso8601String());

    return (response as List)
        .map((json) => EventOrganizerContact.fromJson(json))
        .toList();
  }

  Stream<List<EventOrganizerContact>> watchUnverifiedContacts() {
    return _supabase
        .from('event_organizer_contacts')
        .stream(primaryKey: ['id'])
        .eq('contact_verified', false)
        .map((response) => response
            .map((json) => EventOrganizerContact.fromJson(json))
            .toList());
  }
}
