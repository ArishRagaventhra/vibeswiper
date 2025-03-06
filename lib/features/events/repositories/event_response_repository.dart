import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../models/event_response_model.dart';

final eventResponseRepositoryProvider = Provider((ref) => EventResponseRepository());

class EventResponseRepository {
  final _supabase = SupabaseConfig.client;
  static const String _questionResponsesTable = 'event_question_responses';
  static const String _acceptanceRecordsTable = 'event_acceptance_records';
  static const String _refundAcknowledgmentsTable = 'event_refund_acknowledgments';

  // Question Responses
  Future<List<EventQuestionResponse>> getEventResponses(String eventId) async {
    final response = await _supabase
        .from(_questionResponsesTable)
        .select()
        .eq('event_id', eventId);

    return (response as List)
        .map((json) => EventQuestionResponse.fromJson(json))
        .toList();
  }

  Future<List<EventQuestionResponse>> getUserResponses(String eventId, String userId) async {
    final response = await _supabase
        .from(_questionResponsesTable)
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId);

    return (response as List)
        .map((json) => EventQuestionResponse.fromJson(json))
        .toList();
  }

  Future<void> submitQuestionResponse({
    required String eventId,
    required String userId,
    required String questionId,
    required String responseText,
  }) async {
    await _supabase.from(_questionResponsesTable).insert({
      'event_id': eventId,
      'user_id': userId,
      'question_id': questionId,
      'response_text': responseText,
    });
  }

  // Acceptance Records
  Future<EventAcceptanceRecord?> getAcceptanceRecord(String eventId, String userId) async {
    final response = await _supabase
        .from(_acceptanceRecordsTable)
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null ? EventAcceptanceRecord.fromJson(response) : null;
  }

  Future<void> createAcceptanceRecord({
    required String eventId,
    required String userId,
    required String acceptanceText,
  }) async {
    await _supabase.from(_acceptanceRecordsTable).insert({
      'event_id': eventId,
      'user_id': userId,
      'acceptance_text': acceptanceText,
    });
  }

  // Refund Policy Acknowledgments
  Future<EventRefundAcknowledgment?> getRefundAcknowledgment(String eventId, String userId) async {
    final response = await _supabase
        .from(_refundAcknowledgmentsTable)
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();

    return response != null ? EventRefundAcknowledgment.fromJson(response) : null;
  }

  Future<void> createRefundAcknowledgment({
    required String eventId,
    required String userId,
    required String policyText,
  }) async {
    await _supabase.from(_refundAcknowledgmentsTable).insert({
      'event_id': eventId,
      'user_id': userId,
      'policy_text': policyText,
    });
  }

  // Check if all requirements are completed
  Future<bool> hasCompletedRequirements(String eventId, String userId) async {
    final responses = await getUserResponses(eventId, userId);
    final acceptance = await getAcceptanceRecord(eventId, userId);
    final refundAck = await getRefundAcknowledgment(eventId, userId);

    // Get the event's required questions
    final questions = await _supabase
        .from('event_custom_questions')
        .select()
        .eq('event_id', eventId)
        .eq('is_required', true);

    final requiredQuestionsCount = (questions as List).length;
    final answeredQuestionsCount = responses.length;

    // Check if all required questions are answered and other requirements are met
    return answeredQuestionsCount >= requiredQuestionsCount &&
           acceptance != null &&
           refundAck != null;
  }
}
