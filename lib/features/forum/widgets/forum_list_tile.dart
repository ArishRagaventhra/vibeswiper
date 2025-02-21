import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/forum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/forum_providers.dart';
import '../routes/forum_routes.dart';

class ForumListTile extends ConsumerWidget {
  final Forum forum;
  final bool showJoinButton;
  final bool isJoining;
  final VoidCallback? onJoinTap;
  final VoidCallback? onTap;

  const ForumListTile({
    super.key,
    required this.forum,
    required this.showJoinButton,
    required this.isJoining,
    this.onJoinTap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMember = ref.watch(forumMembershipProvider(forum.id)).value ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isMember ? onTap : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Join this forum to access the chat'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            onLongPress: () => context.push(
              ForumRoutes.forumProfile.replaceFirst(':forumId', forum.id),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Image
                if (forum.bannerImageUrl != null)
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(forum.bannerImageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
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
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Forum Info Row
                      Row(
                        children: [
                          // Profile Image
                          Hero(
                            tag: 'forum_avatar_${forum.id}',
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.colorScheme.shadow.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: forum.profileImageUrl != null
                                  ? CircleAvatar(
                                      radius: 24,
                                      backgroundImage: NetworkImage(forum.profileImageUrl!),
                                    )
                                  : CircleAvatar(
                                      radius: 24,
                                      backgroundColor: theme.colorScheme.primary,
                                      child: Text(
                                        forum.name[0].toUpperCase(),
                                        style: theme.textTheme.titleLarge?.copyWith(
                                          color: theme.colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Forum Name and Description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        forum.name,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (forum.isPrivate)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.lock_outline,
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                                if (forum.description != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    forum.description!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Status and Member Count Row
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            // Activity Status
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Active now',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // Member Count
                            Icon(
                              Icons.group_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${forum.memberCount}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            
                            const Spacer(),
                            
                            // Join/Request Button
                            if (showJoinButton && !isMember)
                              TextButton(
                                onPressed: isJoining ? null : onJoinTap,
                                style: TextButton.styleFrom(
                                  backgroundColor: forum.isPrivate
                                      ? theme.colorScheme.surface
                                      : theme.colorScheme.primary,
                                  foregroundColor: forum.isPrivate
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: forum.isPrivate
                                        ? BorderSide(
                                            color: theme.colorScheme.primary,
                                          )
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Text(
                                  isJoining
                                      ? 'Joining...'
                                      : forum.isPrivate
                                          ? 'Request'
                                          : 'Join',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                            else if (isMember)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Joined',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
