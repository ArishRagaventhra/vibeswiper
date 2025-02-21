import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forum.dart';
import '../providers/forum_providers.dart';
import '../routes/forum_routes.dart';
import 'package:go_router/go_router.dart';

class FeaturedForumItem extends ConsumerWidget {
  final Forum forum;
  final VoidCallback? onJoinTap;

  const FeaturedForumItem({
    super.key,
    required this.forum,
    this.onJoinTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isMember = ref.watch(forumMembershipProvider(forum.id)).value ?? false;

    return Container(
      width: 200,
      height: 220, 
      margin: const EdgeInsets.only(right: 12),
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
          onTap: () => context.push(
            ForumRoutes.forumProfile.replaceFirst(':forumId', forum.id),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner/Profile Image
              SizedBox(
                height: 100,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        image: forum.bannerImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(forum.bannerImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        gradient: forum.bannerImageUrl == null
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.primary.withOpacity(0.8),
                                ],
                              )
                            : null,
                      ),
                    ),
                    if (forum.profileImageUrl != null)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(forum.profileImageUrl!),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Forum Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        forum.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${forum.memberCount} members',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      if (!isMember)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: onJoinTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primaryContainer,
                              foregroundColor: theme.colorScheme.onPrimaryContainer,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            child: Text(forum.isPrivate ? 'Request' : 'Join'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
