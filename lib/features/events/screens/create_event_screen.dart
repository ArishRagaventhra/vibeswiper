import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:scompass_07/config/theme.dart';
import 'package:scompass_07/config/supabase_config.dart';
import 'package:scompass_07/features/events/controllers/event_controller.dart';
import 'package:scompass_07/features/events/controllers/event_wizard_controller.dart';
import 'package:scompass_07/features/events/models/event_model.dart';
import 'package:scompass_07/features/payments/providers/payment_provider.dart';
import 'package:scompass_07/shared/widgets/app_bar.dart';
import 'package:scompass_07/shared/widgets/loading_widget.dart';
import 'package:scompass_07/shared/widgets/dashed_border.dart';
import 'package:scompass_07/shared/widgets/step_progress_indicator.dart';
import '../models/event_requirements_models.dart';
import '../services/event_creation_service.dart';
import '../controllers/event_participant_controller.dart';
import '../utils/media_upload_test.dart';
import '../widgets/date_time_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:scompass_07/features/events/widgets/payment_process_dialog.dart';
import '../widgets/event_contact_form.dart';
import 'package:scompass_07/core/widgets/edge_to_edge_container.dart';
import '../../../shared/widgets/gradient_progress_indicator.dart';
import '../widgets/event_requirements_form.dart';
import 'package:scompass_07/features/events/widgets/event_location_form.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _vibePriceController = TextEditingController();
  final _accessCodeController = TextEditingController();
  final _maxParticipantsController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final List<ImageProvider> _imageProviders = [];
  final List<String> _selectedTags = [];
  final List<EventCustomQuestion> _customQuestions = [];
  bool _hasRefundPolicy = false;
  bool _requiresAcceptance = false;
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  String _selectedCategory = 'academic';
  EventType _eventType = EventType.free;
  EventVisibility _visibility = EventVisibility.public;
  String _currency = 'INR';
  bool _isLoading = false;
  String _loadingText = '';
  final PageController _pageController = PageController(initialPage: 0);
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page?.round() ?? 0;
      });
    });
    _titleController.addListener(_validateCurrentStep);
    _descriptionController.addListener(_validateCurrentStep);
    _priceController.addListener(_validateCurrentStep);
    _locationController.addListener(_validateCurrentStep);
    _cityController.addListener(_validateCurrentStep);
    _countryController.addListener(_validateCurrentStep);
    _accessCodeController.addListener(_validateCurrentStep);
    _maxParticipantsController.addListener(_validateCurrentStep);

    // Add a post-frame callback to set up navigation function
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Register a navigation function that can be called from anywhere
      ref.read(globalNavigationFunctionProvider.notifier).state = () {
        if (mounted && context != null) {
          debugPrint('Global navigation function called - going to /events');
          context.go('/events');
          return true;
        }
        return false;
      };
    });
  }

  @override
  void dispose() {
    // Clear the navigation function when leaving this screen
    // But don't use addPostFrameCallback since it can cause issues
    try {
      // Reset the global navigation function if it belongs to this widget
      final currentNavFn = ref.read(globalNavigationFunctionProvider);
      if (currentNavFn != null) {
        ref.read(globalNavigationFunctionProvider.notifier).state = null;
      }
    } catch (e) {
      // Silently ignore any provider errors during dispose
      debugPrint('Ignoring provider error during dispose: $e');
    }
    
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _accessCodeController.dispose();
    _maxParticipantsController.dispose();
    _pageController.dispose();
    _titleController.removeListener(_validateCurrentStep);
    _descriptionController.removeListener(_validateCurrentStep);
    _priceController.removeListener(_validateCurrentStep);
    _locationController.removeListener(_validateCurrentStep);
    _cityController.removeListener(_validateCurrentStep);
    _countryController.removeListener(_validateCurrentStep);
    _accessCodeController.removeListener(_validateCurrentStep);
    _maxParticipantsController.removeListener(_validateCurrentStep);
    super.dispose();
  }

  Widget _buildStepIndicator(EventWizardState wizardState) {
    final currentStepIndex = EventCreationStep.values.indexOf(wizardState.currentStep);
    final progress = (currentStepIndex + 1) / EventCreationStep.values.length;
    
    return GradientProgressIndicator(
      progress: progress,
      height: 8,
      borderRadius: BorderRadius.circular(24),
      animate: true,
    );
  }

  String _getStepTitle(EventCreationStep step) {
    switch (step) {
      case EventCreationStep.basicInfo:
        return 'Basic Info';
      case EventCreationStep.contactDetails:
        return 'Contact Details';
      case EventCreationStep.media:
        return 'Media';
      case EventCreationStep.dateTime:
        return 'Date & Time';
      case EventCreationStep.requirements:
        return 'Requirements';
      case EventCreationStep.locationDetails:
        return 'Location';
    }
  }

  Widget _buildBasicInfoStep() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
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
                    'Basic Information',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Event Title',
                      hintText: 'Enter a catchy title',
                      prefixIcon: Icon(Icons.title, color: theme.colorScheme.primary),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    maxLength: 500,
                    textInputAction: TextInputAction.next,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Describe your event',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(bottom: 48),
                        child: Icon(Icons.description, color: theme.colorScheme.primary),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                    'Event Details',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category, color: theme.colorScheme.primary),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'academic',
                        child: Row(
                          children: [
                            Icon(Icons.school, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Academic'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'social',
                        child: Row(
                          children: [
                            Icon(Icons.people, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Social'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'sports',
                        child: Row(
                          children: [
                            Icon(Icons.sports, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Sports'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'cultural',
                        child: Row(
                          children: [
                            Icon(Icons.theater_comedy, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Cultural'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'biking',
                        child: Row(
                          children: [
                            Icon(Icons.motorcycle, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Biking'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'wildlife',
                        child: Row(
                          children: [
                            Icon(Icons.forest_rounded, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Wildlife'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Adventure activities',
                        child: Row(
                          children: [
                            Icon(Icons.explore, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Adventure activities'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'water activities',
                        child: Row(
                          children: [
                            Icon(Icons.water, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Water activities'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'food',
                        child: Row(
                          children: [
                            Icon(Icons.restaurant, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Food'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'music',
                        child: Row(
                          children: [
                            Icon(Icons.music_note, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Music'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'art',
                        child: Row(
                          children: [
                            Icon(Icons.art_track, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            const Text('Art'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Event Type',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<EventType>(
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.selected)) {
                            return theme.colorScheme.primary;
                          }
                          return theme.colorScheme.surface;
                        },
                      ),
                      foregroundColor: MaterialStateProperty.resolveWith<Color>(
                        (Set<MaterialState> states) {
                          if (states.contains(MaterialState.selected)) {
                            return theme.colorScheme.onPrimary;
                          }
                          return theme.colorScheme.onSurface;
                        },
                      ),
                    ),
                    segments: const [
                      ButtonSegment<EventType>(
                        value: EventType.free,
                        label: Text('Free'),
                        icon: Icon(Icons.money_off),
                      ),
                      ButtonSegment<EventType>(
                        value: EventType.paid,
                        label: Text('Paid'),
                        icon: Icon(Icons.attach_money),
                      ),
                    ],
                    selected: {_eventType},
                    onSelectionChanged: (Set<EventType> selected) {
                      setState(() {
                        _eventType = selected.first;
                      });
                      if (selected.first == EventType.paid) {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                              top: 20,
                              left: 20,
                              right: 20,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Set Ticket Price',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'List your event for free with no upfront costs. We take a 10% commission only after your event, based on total ticket sales. No hidden fees—just a simple way to host and earn with ease.',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.primary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _priceController,
                                        decoration: InputDecoration(
                                          labelText: 'Actual Price',
                                          prefixText: _currency,
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter the actual price';
                                          }
                                          final price = double.tryParse(value);
                                          if (price == null || price <= 0) {
                                            return 'Please enter a valid price';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _vibePriceController,
                                        decoration: InputDecoration(
                                          labelText: 'Vibe Price',
                                          prefixText: _currency,
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter the Vibe price';
                                          }
                                          final vibePrice = double.tryParse(value);
                                          if (vibePrice == null || vibePrice <= 0) {
                                            return 'Please enter a valid Vibe price';
                                          }
                                          final actualPrice = double.tryParse(_priceController.text) ?? 0;
                                          if (vibePrice > actualPrice) {
                                            return 'Vibe price cannot be higher than actual price';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'The Vibe Price is the offered ticket price for attendees and cannot be higher than the actual event price',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  if (_eventType == EventType.paid) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                              top: 20,
                              left: 20,
                              right: 20,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Set Ticket Price',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: theme.colorScheme.primary,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'List your event for free with no upfront costs. We take a 10% commission only after your event, based on total ticket sales. No hidden fees—just a simple way to host and earn with ease.',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            color: theme.colorScheme.primary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _priceController,
                                        decoration: InputDecoration(
                                          labelText: 'Actual Price',
                                          prefixText: _currency,
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter the actual price';
                                          }
                                          final price = double.tryParse(value);
                                          if (price == null || price <= 0) {
                                            return 'Please enter a valid price';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _vibePriceController,
                                        decoration: InputDecoration(
                                          labelText: 'Vibe Price',
                                          prefixText: _currency,
                                          border: OutlineInputBorder(),
                                        ),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Please enter the Vibe price';
                                          }
                                          final vibePrice = double.tryParse(value);
                                          if (vibePrice == null || vibePrice <= 0) {
                                            return 'Please enter a valid Vibe price';
                                          }
                                          final actualPrice = double.tryParse(_priceController.text) ?? 0;
                                          if (vibePrice > actualPrice) {
                                            return 'Vibe price cannot be higher than actual price';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'The Vibe Price is the offered ticket price for attendees and cannot be higher than the actual event price',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.currency_rupee),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _priceController.text.isEmpty
                                    ? 'Set ticket price'
                                    : '₹${_priceController.text}',
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                    'Event Visibility',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<EventVisibility>(
                    value: _visibility,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Event Visibility',
                      prefixIcon: Icon(Icons.visibility, color: theme.colorScheme.primary),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    items: EventVisibility.values.map((visibility) {
                      IconData icon;
                      Color iconColor;
                      switch (visibility) {
                        case EventVisibility.public:
                          icon = Icons.public;
                          iconColor = Colors.green;
                          break;
                        case EventVisibility.private:
                          icon = Icons.lock;
                          iconColor = Colors.red;
                          break;
                        case EventVisibility.unlisted:
                          icon = Icons.link_off;
                          iconColor = Colors.grey;
                          break;
                      }
                      return DropdownMenuItem(
                        value: visibility,
                        child: Row(
                          children: [
                            Icon(icon, color: iconColor),
                            const SizedBox(width: 8),
                            Text(visibility.name.toUpperCase()),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _visibility = value;
                          if (value != EventVisibility.private) {
                            _accessCodeController.clear();
                          }
                        });
                      }
                    },
                  ),
                  if (_visibility == EventVisibility.private) ...[
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _accessCodeController,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Access Code',
                        hintText: 'Enter a code for private event',
                        prefixIcon: Icon(Icons.key, color: theme.colorScheme.primary),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaStep() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
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
                    'Event Images',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add up to 5 images to showcase your event',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_imageProviders.isEmpty)
                    InkWell(
                      onTap: _pickImage,
                      child: DashedBorder(
                        color: theme.colorScheme.primary.withOpacity(0.5),
                        strokeWidth: 2,
                        gap: 8,
                        radius: 12,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Add Event Images',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to browse',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _imageProviders.length + (_imageProviders.length < 5 ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _imageProviders.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: InkWell(
                                    onTap: _pickImage,
                                    child: DashedBorder(
                                      color: theme.colorScheme.primary.withOpacity(0.5),
                                      strokeWidth: 2,
                                      gap: 8,
                                      radius: 12,
                                      child: Container(
                                        width: 150,
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.add_photo_alternate_outlined,
                                              size: 32,
                                              color: theme.colorScheme.primary,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Add More',
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Padding(
                                padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                                child: _buildImagePreview(_imageProviders[index], index),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(ImageProvider imageProvider, int index) {
    return Stack(
      children: [
        Container(
          width: 150,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton.filled(
            onPressed: () {
              setState(() {
                _imageProviders.removeAt(index);
                _selectedImages.removeAt(index);
              });
            },
            icon: const Icon(Icons.close, size: 18),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(4),
              minimumSize: const Size(32, 32),
            ),
          ),
        ),
      ],
    );
  }

  void _nextStep() {
    _validateCurrentStep();
    
    final wizardState = ref.read(eventWizardProvider);
    
    if (wizardState.isCurrentStepValid) {
      // Save form data before proceeding
      _saveFormData();
      
      if (wizardState.isLastStep) {
        _createEvent();
      } else {
        ref.read(eventWizardProvider.notifier).nextStep();
        // Use Future.delayed to ensure the state is updated before animating
        Future.delayed(Duration.zero, () {
          if (_pageController.hasClients) {
            _pageController.animateToPage(
              EventCreationStep.values.indexOf(ref.read(eventWizardProvider).currentStep),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    } else {
      setState(() {
        // Force UI to refresh and show the validation error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getErrorMessageForCurrentStep()),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _getErrorMessageForCurrentStep() {
    final currentStep = ref.read(eventWizardProvider).currentStep;
    switch (currentStep) {
      case EventCreationStep.basicInfo:
        return 'Please fill in all required fields in Basic Information';
      case EventCreationStep.contactDetails:
        return 'Please provide valid contact details';
      case EventCreationStep.media:
        return 'Please upload at least one image';
      case EventCreationStep.dateTime:
        return 'Please select valid event dates';
      case EventCreationStep.requirements:
        return 'Please complete the event requirements section';
      case EventCreationStep.locationDetails:
        return 'Please provide complete location details';
    }
  }

  void _saveFormData() {
    final currentStep = ref.read(eventWizardProvider).currentStep;
    switch (currentStep) {
      case EventCreationStep.basicInfo:
        ref.read(eventWizardProvider.notifier).updateFormData({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'category': _selectedCategory,
          'event_type': _eventType.toString(),
          'visibility': _visibility.toString(),
          'price': _eventType == EventType.paid ? _priceController.text : '0',
          'vibe_price': _eventType == EventType.paid ? _vibePriceController.text : '0',
          'currency': _currency,
          'access_code': _accessCodeController.text,
          'max_participants': _maxParticipantsController.text,
        });
        break;
      case EventCreationStep.media:
        // Media data is handled separately
        break;
      case EventCreationStep.dateTime:
        // Format recurring pattern based on selected option
        String? recurringPatternJson;
        if (_recurringPattern != 'none') {
          Map<String, dynamic> patternData = {
            'type': _recurringPattern,
            'startTime': _startTime.toIso8601String(),
            'endTime': _endTime.toIso8601String(),
          };
          
          // Add pattern-specific data
          switch (_recurringPattern) {
            case 'daily':
              patternData['interval'] = 1; // Every day
              break;
            case 'weekly':
              patternData['weekdays'] = _selectedWeekdays;
              break;
            case 'monthly':
              patternData['dayOfMonth'] = _startTime.day;
              break;
            case 'custom':
              // Additional custom pattern data would go here
              break;
          }
          
          // Add end condition
          if (_recurringEndDate != null) {
            patternData['endDate'] = _recurringEndDate!.toIso8601String();
          } else {
            patternData['occurrences'] = _occurrenceCount;
          }
          
          recurringPatternJson = json.encode(patternData);
        }
        
        ref.read(eventWizardProvider.notifier).updateFormData({
          'start_time': _startTime.toIso8601String(),
          'end_time': _endTime.toIso8601String(),
          'recurring_pattern': recurringPatternJson,
        });
        break;
      case EventCreationStep.requirements:
        // The requirements data is managed by the EventRequirementsForm widget
        // Only update the flags here, not the text content
        ref.read(eventWizardProvider.notifier).updateFormData({
          'has_refund_policy': _hasRefundPolicy,
          'requires_acceptance': _requiresAcceptance,
        });
        break;
      case EventCreationStep.locationDetails:
        ref.read(eventWizardProvider.notifier).updateFormData({
          'location': _locationController.text,
          'city': _cityController.text,
          'country': _countryController.text,
        });
        break;
      default:
        break;
    }
  }

  void _validateCurrentStep() {
    final currentStep = ref.read(eventWizardProvider).currentStep;
    bool isValid = false;

    switch (currentStep) {
      case EventCreationStep.basicInfo:
        isValid = _validateBasicInfo();
        break;
      case EventCreationStep.contactDetails:
        // Contact form has its own validation
        return;
      case EventCreationStep.media:
        isValid = _validateMedia();
        break;
      case EventCreationStep.dateTime:
        isValid = _validateDateTime();
        break;
      case EventCreationStep.requirements:
        isValid = _validateRequirements();
        break;
      case EventCreationStep.locationDetails:
        isValid = _validateLocation();
        break;
    }

    ref.read(eventWizardProvider.notifier).setStepValidation(currentStep, isValid);
  }

  bool _validateRequirements() {
    // Get the validation state directly from the wizard controller
    // The EventRequirementsForm widget handles its own validation and updates the state
    return ref.read(eventWizardProvider).isCurrentStepValid;
  }

  bool _validateBasicInfo() {
    if (_titleController.text.isEmpty || _titleController.text.length < 3) {
      return false;
    }
    if (_descriptionController.text.isEmpty || _descriptionController.text.length < 10) {
      return false;
    }
    if (_selectedCategory.isEmpty) {
      return false;
    }
    if (_eventType == EventType.paid && (_priceController.text.isEmpty || double.tryParse(_priceController.text) == null)) {
      return false;
    }
    if (_eventType == EventType.paid && (_vibePriceController.text.isEmpty || double.tryParse(_vibePriceController.text) == null)) {
      return false;
    }
    if (_visibility == EventVisibility.private && _accessCodeController.text.isEmpty) {
      return false;
    }
    return true;
  }

  bool _validateMedia() {
    // At least one image is required
    return _selectedImages.isNotEmpty;
  }

  bool _validateDateTime() {
    // If a recurring pattern is selected (not 'none'), allow proceeding regardless of time selection
    if (_recurringPattern != 'none') {
      // For weekly pattern, ensure at least one weekday is selected
      if (_recurringPattern == 'weekly' && _selectedWeekdays.isEmpty) {
        return false;
      }
      // For all other recurring patterns, always return true
      return true;
    }
    
    // For one-time events, only validate that end time is after start time
    // Don't validate against current time since that can cause issues
    if (_endTime.isBefore(_startTime) || _endTime == _startTime) {
      return false;
    }
    return true;
  }

  bool _validateLocation() {
    if (_locationController.text.isEmpty) {
      return false;
    }
    if (_cityController.text.isEmpty) {
      return false;
    }
    if (_countryController.text.isEmpty) {
      return false;
    }
    return true;
  }

  void _previousStep() {
    // Save current form data before going back
    _saveFormData();
    
    final wizardState = ref.read(eventWizardProvider);
    if (wizardState.canGoToPreviousStep) {
      ref.read(eventWizardProvider.notifier).previousStep();
      
      // Use Future.delayed to ensure the state is updated before animating
      Future.delayed(Duration.zero, () {
        if (_pageController.hasClients) {
          _pageController.animateToPage(
            EventCreationStep.values.indexOf(ref.read(eventWizardProvider).currentStep),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _createEvent() async {
    setState(() {
      _isLoading = true;
      _loadingText = 'Creating event...';
    });

    try {
      final wizardState = ref.read(eventWizardProvider);
      final formData = wizardState.formData;
      final locationData = wizardState.locationData;

      // Validate location data
      if (locationData == null || !locationData.isComplete) {
        throw Exception('Location details are required');
      }

      final event = await ref.read(eventCreationServiceProvider).createEvent(
        title: _titleController.text,
        creatorId: SupabaseConfig.client.auth.currentUser!.id,
        description: _descriptionController.text,
        location: locationData.venue!,
        city: locationData.city!,
        country: locationData.country!,
        startTime: _startTime,
        endTime: _endTime,
        eventType: _eventType,
        visibility: _visibility,
        maxParticipants: int.tryParse(_maxParticipantsController.text),
        category: _selectedCategory,
        tags: _selectedTags,
        ticketPrice: _eventType == EventType.paid ? double.parse(_priceController.text) : null,
        vibePrice: _eventType == EventType.paid ? double.parse(_vibePriceController.text) : null,
        currency: _currency,
        mediaFiles: _selectedImages,
        accessCode: _accessCodeController.text,
        organizerName: formData['organizer_name'] ?? '',
        organizerEmail: formData['organizer_email'] ?? '',
        organizerPhone: formData['organizer_phone'] ?? '',
        recurringPattern: formData['recurring_pattern'],
        requirementsData: {
          'refund_policy': formData['refund_policy'],
          'acceptance_text': formData['acceptance_text'],
          'custom_questions': formData['custom_questions'],
          'has_refund_policy': formData['has_refund_policy'],
          'requires_acceptance': formData['requires_acceptance'],
        },
        context: context, // Pass context for navigation after payment
      );

      if (event != null) {
        // Show success message for all events (both free and paid)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Your event has been successfully created!'),
            backgroundColor: Colors.green,
          ),
        );
        if (mounted) {
          context.go('/events');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create event: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
          // Create image providers for previews
          for (final image in images) {
            if (kIsWeb) {
              _imageProviders.add(NetworkImage(image.path));
            } else {
              _imageProviders.add(FileImage(File(image.path)));
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick images: ${e.toString()}')),
        );
      }
    }
  }

  // Define enum for recurring patterns
  String? _recurringPattern; // null (nothing selected), daily, weekly, monthly
  List<String> _selectedWeekdays = [];
  int _occurrenceCount = 10;
  DateTime? _recurringEndDate;

  Widget _buildDateTimeStep() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
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
                    'Date & Time',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set when your event starts and ends',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Recurring Pattern Selection
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Event Frequency',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPatternChip('Daily', 'daily', theme),
                              const SizedBox(width: 8),
                              _buildPatternChip('Weekly', 'weekly', theme),
                              const SizedBox(width: 8),
                              _buildPatternChip('Monthly', 'monthly', theme),
                            ],
                          ),
                        ),
                        
                        // Show additional options based on selected pattern
                        if (_recurringPattern != null) ...[  
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 12),
                          
                          // Weekly pattern options
                          if (_recurringPattern == 'weekly') ...[  
                            Text(
                              'Repeat on',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                _buildWeekdayChip('Mon', theme),
                                _buildWeekdayChip('Tue', theme),
                                _buildWeekdayChip('Wed', theme),
                                _buildWeekdayChip('Thu', theme),
                                _buildWeekdayChip('Fri', theme),
                                _buildWeekdayChip('Sat', theme),
                                _buildWeekdayChip('Sun', theme),
                              ],
                            ),
                          ],
                          
                          // Monthly pattern options
                          if (_recurringPattern == 'monthly') ...[  
                            Text(
                              'Repeats on day ${_startTime.day} of each month',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                          
                          const SizedBox(height: 16),
                          
                          // End condition for recurring events
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: Text('End after', style: theme.textTheme.bodyMedium),
                                  value: _recurringEndDate == null,
                                  groupValue: true,
                                  onChanged: (value) {
                                    setState(() {
                                      _recurringEndDate = null;
                                    });
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  ),
                                  controller: TextEditingController(text: _occurrenceCount.toString()),
                                  onChanged: (value) {
                                    setState(() {
                                      _occurrenceCount = int.tryParse(value) ?? 10;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('occurrences', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RadioListTile<bool>(
                            title: Text('End by specific date', style: theme.textTheme.bodyMedium),
                            value: _recurringEndDate != null,
                            groupValue: true,
                            onChanged: (value) async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _recurringEndDate ?? _startTime.add(const Duration(days: 30)),
                                firstDate: _startTime,
                                lastDate: _startTime.add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _recurringEndDate = picked;
                                });
                              }
                            },
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          if (_recurringEndDate != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 32.0),
                              child: Text(
                                '${_recurringEndDate!.day}/${_recurringEndDate!.month}/${_recurringEndDate!.year}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  DateTimePicker(
                    initialStartDate: _startTime,
                    initialEndDate: _endTime,
                    onDateTimeChanged: (start, end) {
                      setState(() {
                        _startTime = start;
                        _endTime = end;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPatternChip(String label, String pattern, ThemeData theme) {
    final isSelected = _recurringPattern == pattern;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _recurringPattern = pattern;
          if (pattern == 'weekly' && _selectedWeekdays.isEmpty) {
            // Default to the weekday of the selected start date
            final weekday = _getDayAbbreviation(_startTime.weekday);
            _selectedWeekdays = [weekday];
          }
        });
      },
      backgroundColor: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  Widget _buildWeekdayChip(String day, ThemeData theme) {
    final isSelected = _selectedWeekdays.contains(day);
    return FilterChip(
      label: Text(day),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedWeekdays.add(day);
          } else {
            // Don't remove the last weekday
            if (_selectedWeekdays.length > 1) {
              _selectedWeekdays.remove(day);
            }
          }
        });
      },
      backgroundColor: theme.colorScheme.surfaceVariant,
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      checkmarkColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  
  String _getDayAbbreviation(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return 'Mon';
    }
  }

  Widget _buildLocationDetailsStep() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return SingleChildScrollView(
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
                        // Venue Name
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.location_on,
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
                                    'Venue Name',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextFormField(
                                    controller: _locationController,
                                    textInputAction: TextInputAction.next,
                                    style: theme.textTheme.bodyLarge,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Central Park, Conference Hall A',
                                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      floatingLabelBehavior: FloatingLabelBehavior.never,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // City
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.location_city,
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
                                    'City',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextFormField(
                                    controller: _cityController,
                                    textInputAction: TextInputAction.next,
                                    style: theme.textTheme.bodyLarge,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. New York, London',
                                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      floatingLabelBehavior: FloatingLabelBehavior.never,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Country
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.public,
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
                                    'Country',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  TextFormField(
                                    controller: _countryController,
                                    textInputAction: TextInputAction.done,
                                    style: theme.textTheme.bodyLarge,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. United States, United Kingdom',
                                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      floatingLabelBehavior: FloatingLabelBehavior.never,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildCurrentStep() {
    switch (ref.watch(eventWizardProvider).currentStep) {
      case EventCreationStep.basicInfo:
        return _buildBasicInfoStep();
      case EventCreationStep.contactDetails:
        return const EventContactForm();
      case EventCreationStep.media:
        return _buildMediaStep();
      case EventCreationStep.dateTime:
        return _buildDateTimeStep();
      case EventCreationStep.requirements:
        return const EventRequirementsForm();
      case EventCreationStep.locationDetails:
        return const EventLocationForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(navigateToEventsAfterPaymentProvider, (prev, next) {
      if (next == true && mounted) {
        // Navigate to events list
        debugPrint('navigateToEventsAfterPaymentProvider triggered - going to /events');
        context.go('/events');
        // Reset the flag
        ref.read(navigateToEventsAfterPaymentProvider.notifier).state = false;
      }
    });

    final wizardState = ref.watch(eventWizardProvider);
    final theme = Theme.of(context);

    return EdgeToEdgeContainer(
      statusBarColor: Theme.of(context).colorScheme.background,
      navigationBarColor: Theme.of(context).colorScheme.background,
      child: Scaffold(
        appBar: SCompassAppBar(
          title: _getStepTitle(wizardState.currentStep),
          centerTitle: false,
          onBackPressed: () {
            if (wizardState.canGoToPreviousStep) {
              _previousStep();
            } else {
              // Save form data before navigating away
              _saveFormData();
              context.go('/events');
            }
          },
        ),
        body: _isLoading
            ? LoadingWidget(message: _loadingText)
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4, top: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.98, // Takes 98% of the screen width
                          child: _buildStepIndicator(wizardState),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildCurrentStep(),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                if (wizardState.canGoToPreviousStep)
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _previousStep,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: const Text('Back'),
                                    ),
                                  ),
                                if (wizardState.canGoToPreviousStep)
                                  const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: FilledButton(
                                    onPressed: wizardState.isLastStep ? _createEvent : _nextStep,
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    child: Text(
                                      wizardState.isLastStep ? 'Create Event' : 'Continue',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
