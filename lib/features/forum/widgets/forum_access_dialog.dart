import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/custom_text_field.dart';

class ForumAccessDialog extends StatefulWidget {
  const ForumAccessDialog({super.key});

  @override
  State<ForumAccessDialog> createState() => _ForumAccessDialogState();
}

class _ForumAccessDialogState extends State<ForumAccessDialog> {
  final _accessCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter Access Code',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _accessCodeController,
              hintText: 'Access Code',
              inputFormatters: [
                LengthLimitingTextInputFormatter(6),
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                UpperCaseTextFormatter(),
              ],
              keyboardType: TextInputType.text,
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          final code = _accessCodeController.text.trim();
                          if (code.isEmpty) return;
                          Navigator.of(context).pop(code);
                        },
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Join'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Text formatter to convert input to uppercase
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
