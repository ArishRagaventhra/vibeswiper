import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/theme.dart';
import '../models/event_model.dart';
import '../models/event_requirements_models.dart';
import '../providers/event_providers.dart';
import '../repositories/event_requirements_repository.dart';
import '../repositories/event_response_repository.dart';

class EventJoinRequirementsDialog extends ConsumerStatefulWidget {
  final Event event;

  const EventJoinRequirementsDialog({
    super.key,
    required this.event,
  });

  @override
  ConsumerState<EventJoinRequirementsDialog> createState() => _EventJoinRequirementsDialogState();
}

class _EventJoinRequirementsDialogState extends ConsumerState<EventJoinRequirementsDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _questionControllers = {};
  bool _acceptedTerms = false;
  bool _acceptedRefundPolicy = false;
  bool _isLoading = true;
  String? _error;

  // Store the requirements data
  List<EventCustomQuestion> _questions = [];
  EventAcceptanceConfirmation? _acceptanceConfirmation;
  EventRefundPolicy? _refundPolicy;

  @override
  void initState() {
    super.initState();
    _loadRequirements();
  }

  @override
  void dispose() {
    for (var controller in _questionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRequirements() async {
    try {
      setState(() => _isLoading = true);

      final requirementsRepo = ref.read(eventRequirementsRepositoryProvider);
      
      // Load acceptance text
      _acceptanceConfirmation = await requirementsRepo.getEventAcceptanceConfirmation(widget.event.id);

      // Load refund policy
      _refundPolicy = await requirementsRepo.getEventRefundPolicy(widget.event.id);

      // Load questions
      final questionsData = await requirementsRepo.getEventCustomQuestions(widget.event.id);
      _questions = questionsData
          .map((q) => EventCustomQuestion.fromJson(q))
          .toList();

      // Create controllers for each question with default values
      for (var question in _questions) {
        final controller = TextEditingController();
        
        // Set default values based on question type
        switch (question.questionType) {
          case QuestionType.yes_no:
            controller.text = ''; // Empty initially, user must select
            break;
          case QuestionType.multiple_choice:
            controller.text = ''; // Empty initially, user must select
            break;
          case QuestionType.text:
            controller.text = ''; // Empty for text input
            break;
        }
        
        _questionControllers[question.id] = controller;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _error = 'Failed to load requirements: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitResponses() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required questions are answered
    for (var question in _questions) {
      if (question.isRequired && 
          (_questionControllers[question.id]?.text.isEmpty ?? true)) {
        setState(() {
          _error = 'Please answer all required questions';
        });
        return;
      }
    }

    try {
      setState(() => _isLoading = true);

      final userId = ref.read(currentUserProvider)!.id;
      final responseRepo = ref.read(eventResponseRepositoryProvider);

      // Submit question responses
      for (var question in _questions) {
        final response = _questionControllers[question.id]!.text;

        await responseRepo.submitQuestionResponse(
          eventId: widget.event.id,
          userId: userId,
          questionId: question.id,
          responseText: response,
        );
      }

      // Record refund policy acknowledgment first
      if (_refundPolicy != null && _acceptedRefundPolicy) {
        await responseRepo.createRefundAcknowledgment(
          eventId: widget.event.id,
          userId: userId,
          policyText: _refundPolicy!.policyText,
        );
      }

      // Record acceptance last
      if (_acceptanceConfirmation != null && _acceptedTerms) {
        await responseRepo.createAcceptanceRecord(
          eventId: widget.event.id,
          userId: userId,
          acceptanceText: _acceptanceConfirmation!.confirmationText,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return success
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to submit responses: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join Event Requirements',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Custom Questions
              if (_questions.isNotEmpty) ...[
                Text(
                  'Event Questions',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ..._questions.map((question) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildQuestionWidget(question),
                  );
                }),
              ],

              const SizedBox(height: 24),

              // Refund Policy
              if (_refundPolicy != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_refundPolicy!.policyText),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _acceptedRefundPolicy,
                  onChanged: (value) => setState(() => _acceptedRefundPolicy = value!),
                  title: const Text('I acknowledge the refund policy'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],

              const SizedBox(height: 16),

              // Acceptance Text (moved to end)
              if (_acceptanceConfirmation != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_acceptanceConfirmation!.confirmationText),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _acceptedTerms,
                  onChanged: (value) => setState(() => _acceptedTerms = value!),
                  title: const Text('I accept the terms and conditions'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],

              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _submitResponses,
                    child: const Text('Submit & Join'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionWidget(EventCustomQuestion question) {
    final controller = _questionControllers[question.id]!;
    
    switch (question.questionType) {
      case QuestionType.multiple_choice:
        if (question.options == null || question.options!.isEmpty) {
          return Text('Error: No options provided for multiple choice question');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            ...question.options!.map((option) => RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: controller.text,
              onChanged: (value) {
                setState(() {
                  controller.text = value ?? '';
                });
              },
            )).toList(),
            if (question.isRequired && controller.text.isEmpty)
              Text(
                'This question is required',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        );
      
      case QuestionType.yes_no:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              children: [
                Radio<String>(
                  value: 'Yes',
                  groupValue: controller.text,
                  onChanged: (value) {
                    setState(() {
                      controller.text = value ?? '';
                    });
                  },
                ),
                Text('Yes'),
                SizedBox(width: 20),
                Radio<String>(
                  value: 'No',
                  groupValue: controller.text,
                  onChanged: (value) {
                    setState(() {
                      controller.text = value ?? '';
                    });
                  },
                ),
                Text('No'),
              ],
            ),
            if (question.isRequired && controller.text.isEmpty)
              Text(
                'This question is required',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        );
      
      case QuestionType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.questionText,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Enter your answer',
                errorText: question.isRequired && controller.text.isEmpty
                    ? 'This question is required'
                    : null,
              ),
              validator: question.isRequired
                  ? (value) => value?.isEmpty ?? true
                      ? 'This question is required'
                      : null
                  : null,
            ),
          ],
        );
    }
  }
}
