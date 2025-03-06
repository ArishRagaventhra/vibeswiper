import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/event_requirements_models.dart';

final eventRequirementsRepositoryProvider = Provider((ref) => EventRequirementsRepository(
  supabase: Supabase.instance.client,
));

class EventRequirementsRepository {
  final SupabaseClient _supabase;
  static const String _customQuestionsTable = 'event_custom_questions';
  static const String _refundPoliciesTable = 'event_refund_policies';
  static const String _acceptanceConfirmationsTable = 'event_acceptance_confirmations';

  EventRequirementsRepository({required SupabaseClient supabase}) : _supabase = supabase;

  // Create custom questions for an event
  Future<List<EventCustomQuestion>> createCustomQuestions(
    String eventId, 
    List<Map<String, dynamic>> questionsData
  ) async {
    try {
      if (questionsData.isEmpty) return [];
      
      // Prepare the data for insertion
      final List<Map<String, dynamic>> formattedQuestions = questionsData.map((question) {
        final now = DateTime.now().toUtc();
        return {
          'id': const Uuid().v4(),
          'event_id': eventId,
          'question_text': question['questionText'] ?? question['question_text'] ?? '',
          'question_type': question['questionType']?.toString()?.split('.')?.last ?? 
                          question['question_type'] ?? 'text',
          'options': question['options'],
          'is_required': question['isRequired'] ?? question['is_required'] ?? true,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };
      }).toList();
      
      debugPrint('Creating custom questions: $formattedQuestions');
      
      // Insert the questions
      final response = await _supabase
          .from(_customQuestionsTable)
          .insert(formattedQuestions)
          .select();
      
      // Parse and return the created questions
      return (response as List).map((data) => 
        EventCustomQuestion.fromJson(Map<String, dynamic>.from(data))
      ).toList();
    } catch (e, stackTrace) {
      debugPrint('Error creating custom questions: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Create refund policy for an event
  Future<EventRefundPolicy?> createRefundPolicy(
    String eventId, 
    String policyText,
    {int? refundWindowHours, double? refundPercentage}
  ) async {
    try {
      if (policyText.isEmpty) return null;
      
      final now = DateTime.now().toUtc();
      final policyData = {
        'id': const Uuid().v4(),
        'event_id': eventId,
        'policy_text': policyText,
        'refund_window_hours': refundWindowHours,
        'refund_percentage': refundPercentage,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      
      debugPrint('Creating refund policy: $policyData');
      
      final response = await _supabase
          .from(_refundPoliciesTable)
          .insert(policyData)
          .select()
          .single();
      
      return EventRefundPolicy.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('Error creating refund policy: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  // Create acceptance confirmation for an event
  Future<EventAcceptanceConfirmation?> createAcceptanceConfirmation(
    String eventId, 
    String confirmationText
  ) async {
    try {
      if (confirmationText.isEmpty) return null;
      
      final now = DateTime.now().toUtc();
      final confirmationData = {
        'id': const Uuid().v4(),
        'event_id': eventId,
        'confirmation_text': confirmationText,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };
      
      debugPrint('Creating acceptance confirmation: $confirmationData');
      
      final response = await _supabase
          .from(_acceptanceConfirmationsTable)
          .insert(confirmationData)
          .select()
          .single();
      
      return EventAcceptanceConfirmation.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('Error creating acceptance confirmation: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  // Create all requirements for an event
  Future<void> createEventRequirements(
    String eventId,
    Map<String, dynamic> requirementsData
  ) async {
    try {
      debugPrint('Creating event requirements for event $eventId: $requirementsData');
      
      // Create custom questions if they exist
      if (requirementsData.containsKey('custom_questions') && 
          requirementsData['custom_questions'] is List &&
          (requirementsData['custom_questions'] as List).isNotEmpty) {
        await createCustomQuestions(
          eventId, 
          (requirementsData['custom_questions'] as List).cast<Map<String, dynamic>>()
        );
      }
      
      // Create refund policy if it exists
      if (requirementsData.containsKey('refund_policy') && 
          requirementsData['refund_policy'] is String &&
          requirementsData['refund_policy'].toString().trim().isNotEmpty) {
        await createRefundPolicy(
          eventId, 
          requirementsData['refund_policy']
        );
      }
      
      // Create acceptance confirmation if it exists
      if (requirementsData.containsKey('acceptance_text') && 
          requirementsData['acceptance_text'] is String &&
          requirementsData['acceptance_text'].toString().trim().isNotEmpty) {
        await createAcceptanceConfirmation(
          eventId, 
          requirementsData['acceptance_text']
        );
      }
      
      debugPrint('Successfully created all event requirements');
    } catch (e, stackTrace) {
      debugPrint('Error creating event requirements: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get custom questions for an event
  Future<List<Map<String, dynamic>>> getEventCustomQuestions(String eventId) async {
    try {
      final response = await _supabase
          .from(_customQuestionsTable)
          .select()
          .eq('event_id', eventId);
      
      return (response as List).map((data) => 
        Map<String, dynamic>.from(data)
      ).toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting custom questions: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  // Get refund policy for an event
  Future<EventRefundPolicy?> getEventRefundPolicy(String eventId) async {
    try {
      final response = await _supabase
          .from(_refundPoliciesTable)
          .select()
          .eq('event_id', eventId)
          .single();
      
      return EventRefundPolicy.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('Error getting refund policy: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  // Get acceptance confirmation for an event
  Future<EventAcceptanceConfirmation?> getEventAcceptanceConfirmation(String eventId) async {
    try {
      final response = await _supabase
          .from(_acceptanceConfirmationsTable)
          .select()
          .eq('event_id', eventId)
          .single();
      
      return EventAcceptanceConfirmation.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('Error getting acceptance confirmation: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }
}
