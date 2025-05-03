import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  bool _hasViewedAppTerms = false; // Just to track if user has viewed, not for acceptance
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
    final size = MediaQuery.of(context).size;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(false),
            padding: EdgeInsets.zero,
            iconSize: 20,
          ),
        ),
        centerTitle: true,
        title: Text(
          'Join Event',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : SafeArea(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 16, bottom: 32, left: 4),
                                  child: Text(
                                    'Join Event Requirements',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onBackground,
                                    ),
                                    textAlign: TextAlign.left,
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: Row(
                      children: [
                        Text(
                          'Refund Policy',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
                    child: Text(
                      _refundPolicy!.policyText,
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onBackground.withOpacity(0.8),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _acceptedRefundPolicy,
                          onChanged: (value) => setState(() => _acceptedRefundPolicy = value!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          activeColor: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _acceptedRefundPolicy = !_acceptedRefundPolicy),
                          child: Text(
                            'I acknowledge the refund policy',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
              ],

              const SizedBox(height: 16),

              // Event Terms & Conditions (with checkbox - specific to this event)
              if (_acceptanceConfirmation != null) ...[                
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12, left: 4),
                    child: Row(
                      children: [
                        Text(
                          'Event Terms',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onBackground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
                    child: Text(
                      _acceptanceConfirmation!.confirmationText,
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onBackground.withOpacity(0.8),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _acceptedTerms,
                          onChanged: (value) => setState(() => _acceptedTerms = value!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          activeColor: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                          child: Text(
                            'I agree to the event terms and conditions',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onBackground,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // App Privacy Policy & Terms (just text, no checkbox)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Divider(height: 1, thickness: 1, color: theme.dividerColor.withOpacity(0.1)),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24, left: 4, right: 4),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'By using this app, you agree to our ',
                        style: TextStyle(
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: 'Terms of Service',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            _hasViewedAppTerms = true;
                            // Show App Terms of Service
                          },
                      ),
                      TextSpan(
                        text: ' and ',
                        style: TextStyle(
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            _hasViewedAppTerms = true;
                            // Show App Privacy Policy
                          },
                      ),
                      TextSpan(
                        text: '.',
                        style: TextStyle(
                          color: theme.colorScheme.onBackground.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

                              ],
                            ),
                          ),
                        ),
                        // Bottom action buttons - simple minimal design
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          color: isDark ? Colors.black : Colors.white,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: theme.colorScheme.onBackground.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: _acceptedTerms && _acceptedRefundPolicy
                                      ? _submitResponses
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 0,
                                    minimumSize: Size(double.infinity, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.4),
                                    disabledForegroundColor: Colors.white.withOpacity(0.8),
                                  ),
                                  child: Text(
                                    widget.event.vibePrice != null && widget.event.vibePrice! > 0
                                        ? 'Accept & Pay'
                                        : 'Accept & Join',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600, 
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
