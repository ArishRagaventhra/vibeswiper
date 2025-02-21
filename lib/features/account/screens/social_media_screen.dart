import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SocialMediaScreen extends StatelessWidget {
  const SocialMediaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? Colors.black : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;
    final surfaceColor = isDark 
        ? theme.colorScheme.surface 
        : theme.colorScheme.surfaceVariant.withOpacity(0.5);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        title: Text(
          'Social Media',
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSocialMediaTile(
            'Twitter',
            '@scompass',
            Icons.link,
            'https://twitter.com/scompass',
            theme,
            surfaceColor,
          ),
          const SizedBox(height: 12),
          _buildSocialMediaTile(
            'Instagram',
            '@scompass.app',
            Icons.link,
            'https://instagram.com/scompass.app',
            theme,
            surfaceColor,
          ),
          const SizedBox(height: 12),
          _buildSocialMediaTile(
            'Facebook',
            'SCompass',
            Icons.link,
            'https://facebook.com/scompass',
            theme,
            surfaceColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaTile(
    String title,
    String handle,
    IconData icon,
    String url,
    ThemeData theme,
    Color surfaceColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          handle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        trailing: Icon(
          icon,
          color: theme.colorScheme.primary,
        ),
        onTap: () => launchUrl(Uri.parse(url)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }
}
