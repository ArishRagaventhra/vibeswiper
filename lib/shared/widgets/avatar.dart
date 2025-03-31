import 'package:flutter/material.dart';
import 'package:avatar_plus/avatar_plus.dart';
import '../../config/theme.dart';

class Avatar extends StatelessWidget {
  final String? url;
  final double size;
  final String? name; // User's name for generating initials
  final String? userId; // User's ID to ensure consistent avatar

  const Avatar({
    super.key,
    this.url,
    required this.size,
    this.name,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.darkSurfaceColor : AppTheme.surfaceColor;
    final textColor = isDark ? AppTheme.darkPrimaryTextColor : AppTheme.primaryTextColor;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor,
      ),
      child: url != null && url!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(textColor, bgColor),
              ),
            )
          : _buildDefaultAvatar(textColor, bgColor),
    );
  }
  
  Widget _buildDefaultAvatar(Color textColor, Color bgColor) {
    // If userId is provided, use avatar_plus for character avatar
    if (userId != null && userId!.isNotEmpty) {
      return ClipOval(
        child: AvatarPlus(
          userId!,
          height: size,
          width: size,
        ),
      );
    }
    
    // If name is provided, create an initials avatar
    if (name != null && name!.isNotEmpty) {
      final initials = _getInitials(name!);
      return Center(
        child: Text(
          initials,
          style: TextStyle(
            color: textColor,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    
    // Final fallback to person icon
    return Icon(
      Icons.person,
      size: size * 0.6,
      color: textColor.withOpacity(0.5),
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
