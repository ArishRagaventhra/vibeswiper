import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/features/events/controllers/event_controller.dart';

class AccessCodeBottomSheet extends ConsumerStatefulWidget {
  final String eventId;
  final String eventTitle;

  const AccessCodeBottomSheet({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String eventId,
    required String eventTitle,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => AccessCodeBottomSheet(
        eventId: eventId,
        eventTitle: eventTitle,
      ),
    );
  }

  @override
  ConsumerState<AccessCodeBottomSheet> createState() =>
      _AccessCodeBottomSheetState();
}

class _AccessCodeBottomSheetState extends ConsumerState<AccessCodeBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _accessCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _accessCodeController.dispose();
    super.dispose();
  }

  Future<void> _submitAccessCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final success = await ref.read(eventControllerProvider.notifier).joinPrivateEvent(
            widget.eventId,
            _accessCodeController.text.trim(),
          );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined event!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid access code. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Join ${widget.eventTitle}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'This is a private event. Please enter the access code to join.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _accessCodeController,
              decoration: InputDecoration(
                labelText: 'Access Code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the access code';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitAccessCode,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Join Event'),
            ),
          ],
        ),
      ),
    );
  }
}
