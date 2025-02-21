import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/forum_constants.dart';
import '../models/forum_member.dart';
import '../providers/forum_providers.dart';
import '../../auth/providers/current_profile_provider.dart';
import '../../auth/providers/auth_provider.dart';

class ForumMemberScreen extends ConsumerWidget {
  final String forumId;

  const ForumMemberScreen({
    super.key,
    required this.forumId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appBarColor = isDark ? Colors.black : Colors.white;
    final foregroundColor = isDark ? Colors.white : Colors.black;
    final surfaceColor = isDark 
        ? theme.colorScheme.surface 
        : theme.colorScheme.surfaceVariant.withOpacity(0.5);

    final membersAsync = ref.watch(forumMembersProvider(forumId));
    final currentUserAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        title: Text(
          'Forum Members',
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
      body: membersAsync.when(
        data: (members) {
          // Find the current user's member object to check if they're an admin
          final currentUserId = ref.read(authProvider).value?.id;
          final currentMember = members.firstWhere(
            (member) => member.userId == currentUserId,
            orElse: () => ForumMember(
              forumId: forumId,
              userId: currentUserId ?? '',
              role: 'member',
              joinedAt: DateTime.now(),
              lastReadAt: DateTime.now(),
              isMuted: false,
              notificationPreferences: {},
            ),
          );

          return members.isEmpty
              ? const Center(
                  child: Text('No members found'),
                )
              : ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return MemberListTile(
                      member: member,
                      isCurrentUserAdmin: currentMember.isAdmin,
                      onRoleChanged: currentMember.isAdmin
                          ? (newRole) => _updateMemberRole(
                                context,
                                ref,
                                member,
                                newRole,
                              )
                          : null,
                      onRemoveMember: currentMember.isAdmin
                          ? () => _removeMember(
                                context,
                                ref,
                                member,
                              )
                          : null,
                    );
                  },
                );
        },
        error: (error, stack) => Center(
          child: Text('Error: $error'),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Future<void> _updateMemberRole(
    BuildContext context,
    WidgetRef ref,
    ForumMember member,
    String newRole,
  ) async {
    try {
      // TODO: Implement role update in repository
      await ref.read(forumMembersProvider(forumId).notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member role updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating member role: $e')),
        );
      }
    }
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    ForumMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(forumRepositoryProvider).leaveForum(forumId);
      await ref.read(forumMembersProvider(forumId).notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing member: $e')),
        );
      }
    }
  }
}

class MemberListTile extends ConsumerWidget {
  final ForumMember member;
  final bool isCurrentUserAdmin;
  final Function(String)? onRoleChanged;
  final VoidCallback? onRemoveMember;

  const MemberListTile({
    super.key,
    required this.member,
    required this.isCurrentUserAdmin,
    this.onRoleChanged,
    this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(profileByIdProvider(member.userId));
    final theme = Theme.of(context);

    return userProfileAsync.when(
      data: (profile) => ListTile(
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: profile?.avatarUrl == null 
              ? theme.colorScheme.primary.withOpacity(0.1)
              : null,
          backgroundImage: profile?.avatarUrl != null
              ? NetworkImage(profile!.avatarUrl!)
              : null,
          child: profile?.avatarUrl == null
              ? Text(
                  (profile?.fullName?.substring(0, 1) ?? 
                   profile?.username?.substring(0, 1) ?? 
                   'U').toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          profile?.fullName ?? profile?.username ?? 'Unknown User',
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (profile?.username != null)
              Text(
                '@${profile!.username}',
                style: theme.textTheme.bodySmall,
              ),
            Text(
              member.role,
              style: theme.textTheme.bodySmall?.copyWith(
                color: member.isAdmin
                    ? theme.colorScheme.primary
                    : theme.textTheme.bodySmall?.color,
                fontWeight: member.isAdmin ? FontWeight.bold : null,
              ),
            ),
          ],
        ),
        trailing: isCurrentUserAdmin && !member.isAdmin
            ? PopupMenuButton<String>(
                itemBuilder: (context) => [
                  if (onRoleChanged != null)
                    PopupMenuItem(
                      value: 'role',
                      child: Row(
                        children: const [
                          Icon(Icons.edit),
                          SizedBox(width: 8),
                          Text('Change Role'),
                        ],
                      ),
                    ),
                  if (onRemoveMember != null)
                    PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: const [
                          Icon(Icons.person_remove),
                          SizedBox(width: 8),
                          Text('Remove Member'),
                        ],
                      ),
                    ),
                ],
                onSelected: (value) {
                  if (value == 'role' && onRoleChanged != null) {
                    _showRoleDialog(context);
                  } else if (value == 'remove' && onRemoveMember != null) {
                    onRemoveMember!();
                  }
                },
              )
            : null,
      ),
      loading: () => const ListTile(
        leading: CircleAvatar(child: CircularProgressIndicator()),
        title: Text('Loading...'),
      ),
      error: (error, _) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error)),
        title: Text('Error loading user'),
        subtitle: Text(error.toString()),
      ),
    );
  }

  void _showRoleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Role'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Admin'),
              leading: Radio<String>(
                value: ForumConstants.roleAdmin,
                groupValue: member.role,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) onRoleChanged!(value);
                },
              ),
            ),
            ListTile(
              title: const Text('Moderator'),
              leading: Radio<String>(
                value: ForumConstants.roleModerator,
                groupValue: member.role,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) onRoleChanged!(value);
                },
              ),
            ),
            ListTile(
              title: const Text('Member'),
              leading: Radio<String>(
                value: ForumConstants.roleMember,
                groupValue: member.role,
                onChanged: (value) {
                  Navigator.pop(context);
                  if (value != null) onRoleChanged!(value);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
