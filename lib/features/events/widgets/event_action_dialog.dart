import 'package:flutter/material.dart';
import '../models/event_action_model.dart';

class EventActionDialog extends StatefulWidget {
  final EventActionType actionType;
  final Function(String) onConfirm;

  const EventActionDialog({
    Key? key,
    required this.actionType,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<EventActionDialog> createState() => _EventActionDialogState();
}

class _EventActionDialogState extends State<EventActionDialog> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  String get _actionTitle {
    switch (widget.actionType) {
      case EventActionType.cancelled:
        return 'Cancel Event';
      case EventActionType.deleted:
        return 'Delete Event';
    }
  }

  String get _actionMessage {
    switch (widget.actionType) {
      case EventActionType.cancelled:
        return 'Are you sure you want to cancel this event? This will notify all participants.';
      case EventActionType.deleted:
        return 'Are you sure you want to delete this event? This action cannot be undone.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text(_actionTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _actionMessage,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Please provide a reason',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a reason';
                }
                if (value.trim().length < 10) {
                  return 'Please provide a more detailed reason';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onConfirm(_reasonController.text.trim());
              Navigator.of(context).pop();
            }
          },
          style: widget.actionType == EventActionType.deleted
              ? ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                )
              : null,
          child: Text(_actionTitle),
        ),
      ],
    );
  }
}
