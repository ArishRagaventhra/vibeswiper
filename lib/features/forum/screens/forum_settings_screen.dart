import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/forum.dart';
import '../providers/forum_providers.dart';
import '../constants/forum_constants.dart';

class ForumSettingsScreen extends ConsumerStatefulWidget {
  final String forumId;

  const ForumSettingsScreen({
    super.key,
    required this.forumId,
  });

  @override
  ConsumerState<ForumSettingsScreen> createState() => _ForumSettingsScreenState();
}

class _ForumSettingsScreenState extends ConsumerState<ForumSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accessCodeController = TextEditingController();
  bool _isPrivate = false;
  bool _isLoading = false;
  Forum? _forum;

  final _imagePicker = ImagePicker();
  Uint8List? _selectedProfileImage;
  Uint8List? _selectedBannerImage;

  @override
  void initState() {
    super.initState();
    _loadForumData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _accessCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadForumData() async {
    try {
      // First try to find in created forums
      final createdForums = await ref.read(forumRepositoryProvider).getCreatedForums();
      final forum = createdForums.firstWhere(
        (f) => f.id == widget.forumId,
        orElse: () => throw 'Forum not found in created forums',
      );
      
      _forum = forum;

      setState(() {
        _nameController.text = forum.name;
        _descriptionController.text = forum.description ?? '';
        _isPrivate = forum.isPrivate;
        _accessCodeController.text = forum.accessCode ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Only forum creators can modify settings')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _pickImage(bool isProfile) async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: isProfile ? 300 : 800,
        maxHeight: isProfile ? 300 : 400,
        imageQuality: 85,  
      );

      if (image == null) return;

      final imageBytes = await image.readAsBytes();
      
      setState(() {
        if (isProfile) {
          _selectedProfileImage = imageBytes;
          if (_selectedBannerImage != null &&
              _selectedBannerImage!.length == imageBytes.length &&
              _listEquals(_selectedBannerImage!, imageBytes)) {
            _selectedBannerImage = null;
          }
        } else {
          _selectedBannerImage = imageBytes;
          if (_selectedProfileImage != null &&
              _selectedProfileImage!.length == imageBytes.length &&
              _listEquals(_selectedProfileImage!, imageBytes)) {
            _selectedProfileImage = null;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  bool _listEquals<T>(List<T> list1, List<T> list2) {
    if (identical(list1, list2)) return true;
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if (list1[i] != list2[i]) return false;
    }
    return true;
  }

  Future<void> _updateForum() async {
    if (!_formKey.currentState!.validate() || _forum == null) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(forumRepositoryProvider);

      String? profileImageUrl = _forum!.profileImageUrl;
      String? bannerImageUrl = _forum!.bannerImageUrl;

      if (_selectedProfileImage != null) {
        profileImageUrl = await repository.uploadForumImage(
          widget.forumId,
          _selectedProfileImage!,
          ForumConstants.forumProfileImagePath,
        );
      }

      if (_selectedBannerImage != null) {
        bannerImageUrl = await repository.uploadForumImage(
          widget.forumId,
          _selectedBannerImage!,
          ForumConstants.forumBannerImagePath,
        );
      }

      final updatedForum = Forum(
        id: widget.forumId,
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        profileImageUrl: profileImageUrl,
        bannerImageUrl: bannerImageUrl,
        isPrivate: _isPrivate,
        accessCode: _isPrivate && _accessCodeController.text.isNotEmpty
            ? _accessCodeController.text
            : null,
        memberCount: _forum!.memberCount,
        messageCount: _forum!.messageCount,
        createdAt: _forum!.createdAt,
        updatedAt: DateTime.now(),
        createdBy: _forum!.createdBy,
        settings: _forum!.settings,
      );

      await repository.updateForum(updatedForum);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Forum updated successfully')),
        );
        ref.read(createdForumsProvider.notifier).refresh();
        ref.read(joinedForumsProvider.notifier).refresh();
        ref.read(allForumsProvider.notifier).refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating forum: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Forum'),
        content: Text(
          'Are you sure you want to delete "${_forum!.name}"? '
          'This action cannot be undone and will delete all messages and data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(forumDeletionProvider(_forum!.id).future);
        
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Forum deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting forum: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? Colors.black : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;

    if (_forum == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          backgroundColor: appBarColor,
          foregroundColor: foregroundColor,
          elevation: 0,
          title: Text(
            'Forum Settings',
            style: theme.textTheme.titleLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: foregroundColor,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        title: Text(
          'Forum Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: foregroundColor,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            color: foregroundColor,
            onPressed: () => _showDeleteConfirmation(context),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _selectedProfileImage != null
                        ? MemoryImage(_selectedProfileImage!)
                        : _forum!.profileImageUrl != null
                            ? NetworkImage(_forum!.profileImageUrl!)
                            : null,
                    child: _selectedProfileImage == null &&
                            _forum!.profileImageUrl == null
                        ? const Icon(Icons.person, size: 50)
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () => _pickImage(true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            AspectRatio(
              aspectRatio: 2,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      image: _selectedBannerImage != null
                          ? DecorationImage(
                              image: MemoryImage(_selectedBannerImage!),
                              fit: BoxFit.cover,
                            )
                          : _forum!.bannerImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_forum!.bannerImageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                    ),
                    child: _selectedBannerImage == null &&
                            _forum!.bannerImageUrl == null
                        ? const Center(child: Icon(Icons.image, size: 50))
                        : null,
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt),
                      onPressed: () => _pickImage(false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Forum Name',
                hintText: 'Enter forum name',
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
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Enter forum description',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Private Forum'),
              subtitle: const Text(
                'Private forums require an access code to join',
              ),
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),

            if (_isPrivate) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _accessCodeController,
                decoration: const InputDecoration(
                  labelText: 'Access Code',
                  hintText: 'Enter 6-character access code',
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
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _updateForum,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
