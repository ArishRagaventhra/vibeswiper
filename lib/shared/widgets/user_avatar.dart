import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:avatar_plus/avatar_plus.dart';
import 'package:scompass_07/features/auth/providers/current_profile_provider.dart';
import '../../config/theme.dart';

class UserAvatar extends ConsumerWidget {
  final double size;
  final bool showBorder;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.size = 40,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userProfile = ref.watch(currentProfileProvider);
    final bgColor = isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor;
    final textColor = isDark ? AppTheme.darkPrimaryTextColor : AppTheme.primaryTextColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder ? Border.all(
            color: theme.colorScheme.primary,
            width: 2,
          ) : null,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipOval(
          child: userProfile.when(
            data: (profile) {
              if (profile?.avatarUrl != null) {
                return Image.network(
                  profile!.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(
                    textColor,
                    bgColor,
                    profile.id,
                    profile.fullName ?? profile.username,
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return _buildLoadingIndicator(theme);
                  },
                );
              }
              return _buildFallbackAvatar(
                textColor,
                bgColor,
                profile?.id,
                profile?.fullName ?? profile?.username,
              );
            },
            loading: () => _buildLoadingIndicator(theme),
            error: (_, __) => _buildFallbackAvatar(textColor, bgColor, null, null),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(Color textColor, Color bgColor, String? userId, String? name) {
    // If userId is provided, use avatar_plus for character avatar
    if (userId != null && userId.isNotEmpty) {
      return AvatarPlus(
        userId,
        height: size,
        width: size,
      );
    }
    
    // If name is provided, create an initials avatar
    if (name != null && name.isNotEmpty) {
      final initials = _getInitials(name);
      return Container(
        color: bgColor,
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              color: textColor,
              fontSize: size * 0.4,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }
    
    // Final fallback to person icon
    return Container(
      color: bgColor,
      child: Icon(
        Icons.person_rounded,
        size: size * 0.6,
        color: textColor.withOpacity(0.5),
      ),
    );
  }

  Widget _buildLoadingIndicator(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
} 