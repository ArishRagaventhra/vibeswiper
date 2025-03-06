import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/features/events/controllers/event_wizard_controller.dart';

import '../../../config/theme.dart';

class EventLocationForm extends ConsumerStatefulWidget {
  const EventLocationForm({super.key});

  @override
  ConsumerState<EventLocationForm> createState() => _EventLocationFormState();
}

class _EventLocationFormState extends ConsumerState<EventLocationForm> {
  final _formKey = GlobalKey<FormState>();
  final _venueController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();

  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadSavedData();
      _validateAndSave(); // Initial validation
    });
  }

  @override
  void dispose() {
    _venueController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  void _loadSavedData() {
    final locationData = ref.read(eventWizardProvider).locationData;
    if (locationData != null) {
      _venueController.text = locationData.venue ?? '';
      _cityController.text = locationData.city ?? '';
      _countryController.text = locationData.country ?? '';
    }
  }

  void _validateAndSave() {
    final isValid = _formKey.currentState?.validate() ?? false;
    
    if (isValid) {
      ref.read(eventWizardProvider.notifier).updateLocationData(
        venue: _venueController.text,
        city: _cityController.text,
        country: _countryController.text,
      );
    }

    // Always update step validation status
    ref.read(eventWizardProvider.notifier).setStepValidation(
      EventCreationStep.locationDetails, 
      isValid,
    );

    setState(() {
      _isFormValid = isValid;
    });
  }

  String? _validateField(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Form(
      key: _formKey,
      onChanged: _validateAndSave,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
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
                    Text(
                      'Event Location',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Help attendees find your event easily',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceColor : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLocationField(
                            controller: _venueController,
                            label: 'Venue Name',
                            hint: 'e.g. Central Park, Conference Hall A',
                            icon: Icons.location_on,
                            validator: (value) => _validateField(value, 'Venue name'),
                          ),
                          const SizedBox(height: 24),
                          _buildLocationField(
                            controller: _cityController,
                            label: 'City',
                            hint: 'e.g. New York, London',
                            icon: Icons.location_city,
                            validator: (value) => _validateField(value, 'City'),
                          ),
                          const SizedBox(height: 24),
                          _buildLocationField(
                            controller: _countryController,
                            label: 'Country',
                            hint: 'e.g. United States, United Kingdom',
                            icon: Icons.public,
                            validator: (value) => _validateField(value, 'Country'),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0066FF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF0066FF).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: const Color(0xFF0066FF),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Make sure to provide accurate location details to help attendees find your event easily.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF0066FF),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              TextFormField(
                controller: controller,
                textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                style: theme.textTheme.bodyLarge,
                validator: validator,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  errorStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
