// Flutter imports
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/config/theme.dart';
import 'package:scompass_07/features/profile/providers/profile_provider.dart';
import 'package:scompass_07/features/profile/models/profile_model.dart';  
import 'package:scompass_07/shared/widgets/app_bar.dart';
import 'package:scompass_07/shared/widgets/loading_widget.dart';
import 'package:scompass_07/shared/widgets/avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;
  late TextEditingController _bioController;
  late TextEditingController _websiteController;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Initialize with empty controllers first
    _usernameController = TextEditingController();
    _fullNameController = TextEditingController();
    _bioController = TextEditingController();
    _websiteController = TextEditingController();
  }

  void _initializeControllers(Profile? profile) {
    if (!_initialized && profile != null) {
      _usernameController.text = profile.username ?? '';
      _fullNameController.text = profile.fullName ?? '';
      _bioController.text = profile.bio ?? '';
      _websiteController.text = profile.website ?? '';
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (_isLoading) return;

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(currentProfileProvider.notifier).updateProfile(
        username: _usernameController.text,
        fullName: _fullNameController.text,
        bio: _bioController.text,
        website: _websiteController.text,
      );

      // Force refresh the profile data
      ref.invalidate(currentProfileProvider);
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Pop back to previous screen
        if (context.mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      await ref.read(currentProfileProvider.notifier).updateAvatar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile picture: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentProfileProvider);
    
    return profileAsync.when(
      data: (profile) {
        // Initialize controllers when profile data is available
        _initializeControllers(profile);
        
        if (_isLoading) {
          return const LoadingWidget();
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: SCompassAppBar(
            title: 'Edit Profile',
            actions: [
              TextButton.icon(
                onPressed: _updateProfile,
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Picture Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Hero(
                              tag: 'profile-${profile?.id ?? "new"}',
                              child: Avatar(
                                url: profile?.avatarUrl,
                                size: 120,
                                name: profile?.fullName ?? profile?.username,
                                userId: profile?.id,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.shadowColor.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 20,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Change Profile Picture',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Form Section
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profile Information',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _usernameController,
                          label: 'Username',
                          prefixIcon: Icons.alternate_email,
                          prefixText: '@',
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a username';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _fullNameController,
                          label: 'Full Name',
                          prefixIcon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _bioController,
                          label: 'Bio',
                          prefixIcon: Icons.info_outline,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _websiteController,
                          label: 'Website',
                          prefixIcon: Icons.link,
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, stack) => Scaffold(
        appBar: const SCompassAppBar(title: 'Edit Profile'),
        body: Center(
          child: Text('Error loading profile: $error'),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    String? prefixText,
    int? maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(prefixIcon),
        prefixText: prefixText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ),
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
    );
  }
}
