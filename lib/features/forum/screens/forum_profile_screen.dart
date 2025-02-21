import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/forum.dart';
import '../providers/forum_providers.dart';
import '../routes/forum_routes.dart';
import '../../../shared/widgets/loading_widget.dart';

class ForumProfileScreen extends ConsumerWidget {
  final String forumId;

  const ForumProfileScreen({
    super.key,
    required this.forumId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forumAsync = ref.watch(forumProvider(forumId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(
              ForumRoutes.forumSettings.replaceFirst(':forumId', forumId),
            ),
          ),
        ],
      ),
      body: forumAsync.when(
        data: (forum) => RefreshIndicator(
          onRefresh: () => ref.refresh(forumProvider(forumId).future),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: forum.profileImageUrl != null
                                ? NetworkImage(forum.profileImageUrl!)
                                : null,
                            child: forum.profileImageUrl == null
                                ? Text(
                                    forum.name[0].toUpperCase(),
                                    style: theme.textTheme.headlineMedium,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  forum.name,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (forum.isPrivate)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.lock,
                                              size: 16,
                                              color: theme.colorScheme.onSecondaryContainer,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Private',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                color: theme.colorScheme.onSecondaryContainer,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (forum.isPrivate)
                                      const SizedBox(width: 8),
                                    Text(
                                      '${forum.memberCount} members',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (forum.description != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          forum.description!,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => context.push(
                                ForumRoutes.forumChat.replaceFirst(':forumId', forumId),
                              ),
                              icon: const Icon(Icons.chat),
                              label: const Text('Open Chat'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                ForumRoutes.forumMembers.replaceFirst(':forumId', forumId),
                              ),
                              icon: const Icon(Icons.group),
                              label: const Text('View Members'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading forum profile',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.refresh(forumProvider(forumId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
