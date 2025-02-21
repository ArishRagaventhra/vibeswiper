import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/forum_constants.dart';
import '../models/forum.dart';
import '../providers/forum_providers.dart';
import 'package:uuid/uuid.dart';

class ForumCreateScreen extends ConsumerStatefulWidget {
  const ForumCreateScreen({super.key});

  @override
  ConsumerState<ForumCreateScreen> createState() => _ForumCreateScreenState();
}

class _ForumCreateScreenState extends ConsumerState<ForumCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accessCodeController = TextEditingController();
  bool _isPrivate = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  Future<void> _createForum() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final forum = Forum(
        id: const Uuid().v4(),  // Temporary ID that will be replaced by Supabase
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        isPrivate: _isPrivate,
        accessCode: _isPrivate && _accessCodeController.text.isNotEmpty
            ? _accessCodeController.text
            : null,
        memberCount: 1,  // Creator will be the first member
        messageCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: '',  // Will be set by repository
        settings: ForumConstants.defaultForumSettings,
      );

      await ref.read(forumRepositoryProvider).createForum(forum);
      
      if (mounted) {
        context.pop();
        // Refresh both created and joined forums lists
        ref.read(createdForumsProvider.notifier).refresh();
        ref.read(joinedForumsProvider.notifier).refresh();
        // Also refresh the discover tab
        ref.read(allForumsProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating forum: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Create Forum',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Forum Icon Preview
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.forum_outlined,
                    size: 48,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Forum Name Field
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _nameController,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  labelText: 'Forum Name',
                  hintText: 'Enter forum name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.group_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a forum name';
                  }
                  if (value.length < ForumConstants.minForumNameLength) {
                    return 'Name must be at least ${ForumConstants.minForumNameLength} characters';
                  }
                  if (value.length > ForumConstants.maxForumNameLength) {
                    return 'Name must be less than ${ForumConstants.maxForumNameLength} characters';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 24),
            // Description Field
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _descriptionController,
                style: theme.textTheme.bodyLarge,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'What is your forum about?',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  prefixIcon: Icon(
                    Icons.description_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Privacy Section
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Privacy Settings',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    title: Text(
                      'Private Forum',
                      style: theme.textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      'Private forums require an access code to join',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: _isPrivate,
                    onChanged: (value) => setState(() => _isPrivate = value),
                  ),
                  if (_isPrivate) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextFormField(
                        controller: _accessCodeController,
                        style: theme.textTheme.titleMedium,
                        decoration: InputDecoration(
                          labelText: 'Access Code',
                          hintText: 'Enter 6-character code',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.1),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline.withOpacity(0.1),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.password_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        maxLength: 6,
                        validator: (value) {
                          if (_isPrivate) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an access code';
                            }
                            if (value.length != 6) {
                              return 'Access code must be 6 characters';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Create Button
            FilledButton(
              onPressed: _isLoading ? null : _createForum,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline,
                          color: theme.colorScheme.onPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Create Forum',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
