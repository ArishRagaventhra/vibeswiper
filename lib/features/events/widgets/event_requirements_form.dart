import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/event_wizard_controller.dart';
import '../models/event_requirements_models.dart';

class EventRequirementsForm extends ConsumerStatefulWidget {
  const EventRequirementsForm({super.key});

  @override
  ConsumerState<EventRequirementsForm> createState() => _EventRequirementsFormState();
}

class _EventRequirementsFormState extends ConsumerState<EventRequirementsForm> {
  final List<EventCustomQuestion> _customQuestions = [];
  final TextEditingController _refundPolicyController = TextEditingController();
  final TextEditingController _acceptanceTextController = TextEditingController();
  bool _initialized = false;
  
  // Add validation state variables
  bool _refundPolicyValid = true;
  bool _acceptanceTextValid = true;
  bool _customQuestionsValid = true;

  @override
  void initState() {
    super.initState();
    // Load saved data from wizard controller after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSavedData();
    });

    // Add listeners for continuous validation and saving
    _refundPolicyController.addListener(_saveAndValidate);
    _acceptanceTextController.addListener(_saveAndValidate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Schedule loading data after the current build phase is complete
    // This prevents modifying provider state during build
    if (!_initialized) {
      Future.microtask(() {
        if (mounted) {
          _loadSavedData();
        }
      });
    }
  }

  void _loadSavedData() {
    if (!mounted) return;
    
    // Get the latest form data from the wizard controller
    final formData = ref.read(eventWizardProvider).formData;
    
    // Only update the controllers if the text is different to avoid cursor jumps
    if (_refundPolicyController.text != (formData['refund_policy'] ?? '')) {
      _refundPolicyController.text = formData['refund_policy'] ?? '';
    }
    
    if (_acceptanceTextController.text != (formData['acceptance_text'] ?? '')) {
      _acceptanceTextController.text = formData['acceptance_text'] ?? '';
    }
    
    // Update custom questions if they exist in form data
    if (formData['custom_questions'] != null) {
      setState(() {
        _customQuestions.clear();
        _customQuestions.addAll(
          (formData['custom_questions'] as List).map((q) => EventCustomQuestion.fromJson(q)).toList(),
        );
      });
    }
    
    // Mark as initialized
    _initialized = true;
    
    // Validate after loading data - but use microtask to avoid modifying state during build
    Future.microtask(() {
      if (mounted) {
        _validateOnly();
      }
    });
  }
  
  void _validateOnly() {
    if (!mounted) return;
    
    // Check if refund policy and acceptance text are valid
    final isRefundPolicyValid = _refundPolicyController.text.trim().isNotEmpty;
    final isAcceptanceTextValid = _acceptanceTextController.text.trim().isNotEmpty;
    
    // Check if all custom questions are valid
    final hasValidQuestions = _customQuestions.isEmpty || _customQuestions.every((q) =>
        q.questionText.isNotEmpty &&
        (q.questionType != QuestionType.multiple_choice ||
            (q.options?.length ?? 0) >= 2));

    // Update validation state
    setState(() {
      _refundPolicyValid = isRefundPolicyValid;
      _acceptanceTextValid = isAcceptanceTextValid;
      _customQuestionsValid = hasValidQuestions;
    });
  }

  void _addCustomQuestion() {
    setState(() {
      _customQuestions.add(
        EventCustomQuestion(
          id: DateTime.now().toString(),
          eventId: '',
          questionText: '',
          questionType: QuestionType.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    });
    _saveAndValidate();
  }

  void _removeCustomQuestion(int index) {
    setState(() {
      _customQuestions.removeAt(index);
    });
    _saveAndValidate();
  }

  void _saveAndValidate() {
    if (!mounted) return;
    
    // First, just validate locally (this doesn't modify the provider)
    _validateOnly();
    
    // Then schedule the provider update after the current build phase
    Future.microtask(() {
      if (!mounted) return;
      
      // Save form data immediately
      Map<String, dynamic> updatedData = {
        'refund_policy': _refundPolicyController.text,
        'acceptance_text': _acceptanceTextController.text,
        'custom_questions': _customQuestions.map((q) => q.toJson()).toList(),
      };
      
      // Ensure we're not losing any existing data
      final currentFormData = ref.read(eventWizardProvider).formData;
      if (currentFormData.containsKey('has_refund_policy')) {
        updatedData['has_refund_policy'] = currentFormData['has_refund_policy'];
      }
      if (currentFormData.containsKey('requires_acceptance')) {
        updatedData['requires_acceptance'] = currentFormData['requires_acceptance'];
      }
      
      // Update the provider state after the build is complete
      ref.read(eventWizardProvider.notifier).updateFormData(updatedData);
      
      // Update validation state in the wizard controller
      ref.read(eventWizardProvider.notifier).setStepValidation(
        EventCreationStep.requirements,
        _refundPolicyValid && _acceptanceTextValid && _customQuestionsValid,
      );
    });
  }

  @override
  void dispose() {
    _refundPolicyController.dispose();
    _acceptanceTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Refund Policy Section
            _buildSectionCard(
              title: 'Refund Policy',
              icon: Icons.money_off,
              color: colorScheme.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Specify your refund policy for participants',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _refundPolicyController,
                    decoration: InputDecoration(
                      hintText: 'Enter your refund policy details...',
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _refundPolicyValid 
                              ? colorScheme.outline.withOpacity(0.2)
                              : colorScheme.error,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _refundPolicyValid ? colorScheme.primary : colorScheme.error,
                          width: 2,
                        ),
                      ),
                      errorText: !_refundPolicyValid ? 'Please enter refund policy details' : null,
                    ),
                    maxLines: 4,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Terms and Conditions Section
            _buildSectionCard(
              title: 'Terms and Conditions',
              icon: Icons.gavel,
              color: colorScheme.secondary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Specify the terms participants must accept',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _acceptanceTextController,
                    decoration: InputDecoration(
                      hintText: 'Enter the terms participants must accept...',
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _acceptanceTextValid 
                              ? colorScheme.outline.withOpacity(0.2)
                              : colorScheme.error,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _acceptanceTextValid ? colorScheme.secondary : colorScheme.error,
                          width: 2,
                        ),
                      ),
                      errorText: !_acceptanceTextValid ? 'Please enter terms and conditions' : null,
                    ),
                    maxLines: 4,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Custom Questions Section
            _buildSectionCard(
              title: 'Custom Questions',
              icon: Icons.help_outline,
              color: colorScheme.tertiary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add questions for your participants to answer',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_customQuestions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.question_answer_outlined,
                              size: 48,
                              color: colorScheme.tertiary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No custom questions yet',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Add questions to gather information from participants',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _customQuestions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildQuestionCard(index, theme);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _addCustomQuestion,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Question'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (!_customQuestionsValid && _customQuestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please ensure all questions have text and multiple choice questions have at least 2 options',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
  
  Widget _buildQuestionCard(int index, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final question = _customQuestions[index];
    
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${index + 1}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error),
                  tooltip: 'Remove question',
                  onPressed: () => _removeCustomQuestion(index),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: question.questionText,
              decoration: InputDecoration(
                labelText: 'Question Text',
                hintText: 'Enter your question here...',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: question.questionText.isEmpty ? 'Please enter question text' : null,
              ),
              onChanged: (value) {
                setState(() {
                  _customQuestions[index] = question.copyWith(
                    questionText: value,
                  );
                });
                _saveAndValidate();
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<QuestionType>(
              value: question.questionType,
              decoration: InputDecoration(
                labelText: 'Question Type',
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: QuestionType.values.map((type) {
                String label;
                IconData icon;
                
                switch (type) {
                  case QuestionType.text:
                    label = 'Text';
                    icon = Icons.text_fields;
                    break;
                  case QuestionType.multiple_choice:
                    label = 'Multiple Choice';
                    icon = Icons.list;
                    break;
                  case QuestionType.yes_no:
                    label = 'Yes/No';
                    icon = Icons.check_circle_outline;
                    break;
                }
                
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                      Text(label),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _customQuestions[index] = question.copyWith(
                      questionType: value,
                      options: value == QuestionType.multiple_choice ? ['Option 1', 'Option 2'] : null,
                    );
                  });
                  _saveAndValidate();
                }
              },
            ),
            if (question.questionType == QuestionType.multiple_choice) ...[
              const SizedBox(height: 16),
              Text(
                'Options',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...question.options?.asMap().entries.map((entry) {
                int optionIndex = entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: entry.value,
                          decoration: InputDecoration(
                            labelText: 'Option ${optionIndex + 1}',
                            filled: true,
                            fillColor: colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            errorText: entry.value.isEmpty ? 'Please enter option text' : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              List<String> updatedOptions = List.from(question.options ?? []);
                              updatedOptions[optionIndex] = value;
                              _customQuestions[index] = question.copyWith(
                                options: updatedOptions,
                              );
                            });
                            _saveAndValidate();
                          },
                        ),
                      ),
                      if (optionIndex > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: 'Remove option',
                          onPressed: () {
                            setState(() {
                              List<String> updatedOptions = List.from(question.options ?? []);
                              updatedOptions.removeAt(optionIndex);
                              _customQuestions[index] = question.copyWith(
                                options: updatedOptions,
                              );
                            });
                            _saveAndValidate();
                          },
                        ),
                    ],
                  ),
                );
              }).toList() ?? [],
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    List<String> updatedOptions = List.from(question.options ?? []);
                    updatedOptions.add('New Option');
                    _customQuestions[index] = question.copyWith(
                      options: updatedOptions,
                    );
                  });
                  _saveAndValidate();
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Option'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}