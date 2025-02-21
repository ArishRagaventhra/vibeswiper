import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/config/theme.dart';
import 'package:scompass_07/features/events/controllers/event_wizard_controller.dart';

class EventContactForm extends ConsumerStatefulWidget {
  const EventContactForm({super.key});

  @override
  ConsumerState<EventContactForm> createState() => _EventContactFormState();
}

class _EventContactFormState extends ConsumerState<EventContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load saved contact info from wizard controller after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formData = ref.read(eventWizardProvider).formData;
      setState(() {
        _nameController.text = formData['organizer_name'] ?? '';
        _emailController.text = formData['organizer_email'] ?? '';
        _phoneController.text = formData['organizer_phone'] ?? '';
      });
      
      // Validate form if data exists
      if (_nameController.text.isNotEmpty || 
          _emailController.text.isNotEmpty || 
          _phoneController.text.isNotEmpty) {
        _validateForm();
      }
    });

    // Add listeners for continuous validation
    _nameController.addListener(_validateForm);
    _emailController.addListener(_validateForm);
    _phoneController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _nameController.removeListener(_validateForm);
    _emailController.removeListener(_validateForm);
    _phoneController.removeListener(_validateForm);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^\+?[\d\s-]{10,}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  void _validateForm() {
    if (!mounted) return;
    
    final isValid = _formKey.currentState?.validate() ?? false;
    
    if (isValid) {
      // Save the contact info to wizard controller
      ref.read(eventWizardProvider.notifier).updateFormData({
        'organizer_name': _nameController.text,
        'organizer_email': _emailController.text,
        'organizer_phone': _phoneController.text,
      });
    }
    
    ref.read(eventWizardProvider.notifier).setStepValidation(
      EventCreationStep.contactDetails,
      isValid,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: _validateForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact Details',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please provide accurate contact information for event verification',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Contact Form Fields
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Name Field
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Enter your full name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorMaxLines: 2,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Full name is required';
                        }
                        if (value.trim().length < 3) {
                          return 'Name must be at least 3 characters long';
                        }
                        return null;
                      },
                      onChanged: (_) => _validateForm(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorMaxLines: 2,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                      onChanged: (_) => _validateForm(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Phone Field
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter your phone number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorMaxLines: 2,
                      ),
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                      onChanged: (_) => _validateForm(),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Verification Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Verification Notice',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We will verify your contact information to ensure the authenticity of your event. If we cannot reach you or if the provided information is incorrect, your event will be automatically deleted after 24 hours.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '• Please ensure your contact details are accurate\n• Keep your phone available for verification\n• Check your email for verification messages',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: Colors.grey[700],
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
}
