import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// TODO: Create notification settings provider
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, Map<String, bool>>((ref) {
  return NotificationSettingsNotifier();
});

class NotificationSettingsNotifier extends StateNotifier<Map<String, bool>> {
  NotificationSettingsNotifier() : super({
    'events': true,
    'messages': true,
    'followers': true,
    'updates': true,
  });

  void toggleSetting(String key) {
    state = {...state, key: !(state[key] ?? false)};
  }
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? Colors.black : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        title: Text(
          'Notification Settings',
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
        children: [
          _buildSection(
            title: 'Events',
            children: [
              _buildNotificationTile(
                'Event Updates',
                'Get notified about event changes and updates',
                settings['events'] ?? false,
                (value) => ref.read(notificationSettingsProvider.notifier).toggleSetting('events'),
                theme,
              ),
            ],
            theme: theme,
          ),
          _buildSection(
            title: 'Messages',
            children: [
              _buildNotificationTile(
                'Direct Messages',
                'Get notified when you receive messages',
                settings['messages'] ?? false,
                (value) => ref.read(notificationSettingsProvider.notifier).toggleSetting('messages'),
                theme,
              ),
            ],
            theme: theme,
          ),
          _buildSection(
            title: 'Social',
            children: [
              _buildNotificationTile(
                'New Followers',
                'Get notified when someone follows you',
                settings['followers'] ?? false,
                (value) => ref.read(notificationSettingsProvider.notifier).toggleSetting('followers'),
                theme,
              ),
            ],
            theme: theme,
          ),
          _buildSection(
            title: 'App Updates',
            children: [
              _buildNotificationTile(
                'App Updates',
                'Get notified about new features and updates',
                settings['updates'] ?? false,
                (value) => ref.read(notificationSettingsProvider.notifier).toggleSetting('updates'),
                theme,
              ),
            ],
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildNotificationTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
    ThemeData theme,
  ) {
    return SwitchListTile(
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.textTheme.bodySmall?.color,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: theme.colorScheme.primary,
      inactiveTrackColor: theme.colorScheme.surfaceVariant,
    );
  }
}
