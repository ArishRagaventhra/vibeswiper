import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/event_model.dart';
import '../controllers/event_controller.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../core/widgets/edge_to_edge_container.dart';

class EditEventScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EditEventScreen({
    Key? key,
    required this.eventId,
  }) : super(key: key);

  @override
  ConsumerState<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends ConsumerState<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;
  late TextEditingController _maxParticipantsController;
  DateTime? _startTime;
  DateTime? _endTime;
  EventVisibility? _visibility;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _maxParticipantsController = TextEditingController();
    _loadEventDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _maxParticipantsController.dispose();
    super.dispose();
  }

  Future<void> _loadEventDetails() async {
    final eventAsync = await ref.read(eventDetailsProvider(widget.eventId).future);
    if (eventAsync != null) {
      setState(() {
        _titleController.text = eventAsync.title;
        _descriptionController.text = eventAsync.description ?? '';
        _locationController.text = eventAsync.location ?? '';
        _maxParticipantsController.text = eventAsync.maxParticipants?.toString() ?? '';
        _startTime = eventAsync.startTime;
        _endTime = eventAsync.endTime;
        _visibility = eventAsync.visibility;
      });
    }
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validations
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event dates')),
      );
      return;
    }

    // Prevent backdating events
    final now = DateTime.now();
    if (_startTime!.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot set event start time to past')),
      );
      return;
    }

    // Ensure minimum event duration
    if (_endTime!.difference(_startTime!).inHours < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event must be at least 1 hour long')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final eventController = ref.read(eventControllerProvider.notifier);
      final currentEvent = await ref.read(eventDetailsProvider(widget.eventId).future);
      
      if (currentEvent == null) {
        throw Exception('Event not found');
      }

      // Create updated event with only editable fields
      final updatedEvent = currentEvent.copyWith(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        maxParticipants: _maxParticipantsController.text.isEmpty 
          ? null 
          : int.parse(_maxParticipantsController.text),
        startTime: _startTime!,
        endTime: _endTime!,
        visibility: _visibility!,
        updatedAt: DateTime.now(),
      );

      final result = await eventController.updateEvent(updatedEvent);
      
      if (result == null) {
        throw Exception('Failed to update event');
      }

      // Invalidate the event details provider to force a refresh
      ref.invalidate(eventDetailsProvider(widget.eventId));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update event: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: isStartTime ? (_startTime ?? DateTime.now()) : (_endTime ?? _startTime ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null) return;

    if (!mounted) return;

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isStartTime ? (_startTime ?? DateTime.now()) : (_endTime ?? _startTime ?? DateTime.now()),
      ),
    );

    if (selectedTime == null) return;

    setState(() {
      final DateTime selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      if (isStartTime) {
        _startTime = selectedDateTime;
        // Auto-adjust end time if needed
        if (_endTime == null || _endTime!.isBefore(_startTime!)) {
          _endTime = _startTime!.add(const Duration(hours: 2));
        }
      } else {
        _endTime = selectedDateTime;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return EdgeToEdgeContainer(
      statusBarColor: theme.colorScheme.background,
      navigationBarColor: theme.colorScheme.background,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Edit Event',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: theme.colorScheme.background,
          elevation: 0,
          actions: [
            if (!_isLoading)
              TextButton.icon(
                onPressed: _updateEvent,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
              ),
          ],
        ),
        body: _isLoading
            ? const LoadingWidget()
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  children: [
                    // Event Title
                    TextFormField(
                      controller: _titleController,
                      style: theme.textTheme.titleMedium,
                      decoration: InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'Enter a catchy title',
                        prefixIcon: const Icon(Icons.title_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      maxLength: 100,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        hintText: 'What\'s this event about?',
                        prefixIcon: const Icon(Icons.description_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignLabelWithHint: true,
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      maxLength: 1000,
                      maxLines: 5,
                      minLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Location
                    TextFormField(
                      controller: _locationController,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'Where is it happening?',
                        prefixIcon: const Icon(Icons.location_on_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                      ),
                      maxLength: 200,
                    ),
                    const SizedBox(height: 24),

                    // Date and Time Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Date & Time',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Start Time
                          InkWell(
                            onTap: () => _selectDateTime(context, true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Starts',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _startTime != null
                                              ? DateFormat('MMM dd, yyyy - hh:mm a').format(_startTime!)
                                              : 'Select start time',
                                          style: theme.textTheme.bodyLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // End Time
                          InkWell(
                            onTap: () => _selectDateTime(context, false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.event_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ends',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _endTime != null
                                              ? DateFormat('MMM dd, yyyy - hh:mm a').format(_endTime!)
                                              : 'Select end time',
                                          style: theme.textTheme.bodyLarge,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Event Settings Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Event Settings',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Maximum Participants
                          TextFormField(
                            controller: _maxParticipantsController,
                            style: theme.textTheme.bodyLarge,
                            decoration: InputDecoration(
                              labelText: 'Maximum Participants',
                              hintText: 'Leave empty for unlimited',
                              prefixIcon: const Icon(Icons.group_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final number = int.tryParse(value);
                                if (number == null || number < 1) {
                                  return 'Enter a valid number';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          // Event Visibility
                          DropdownButtonFormField<EventVisibility>(
                            value: _visibility,
                            decoration: InputDecoration(
                              labelText: 'Event Visibility',
                              prefixIcon: const Icon(Icons.visibility_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              floatingLabelBehavior: FloatingLabelBehavior.always,
                            ),
                            items: EventVisibility.values.map((visibility) {
                              return DropdownMenuItem(
                                value: visibility,
                                child: Text(
                                  visibility.name.toUpperCase(),
                                  style: theme.textTheme.bodyLarge,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _visibility = value);
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select event visibility';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }
}
