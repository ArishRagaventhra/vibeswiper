import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scompass_07/shared/widgets/error_widget.dart';
import '../models/forum.dart';
import '../providers/forum_providers.dart';
import '../providers/forum_search_provider.dart';
import '../providers/featured_forums_provider.dart';
import '../routes/forum_routes.dart';
import '../widgets/forum_list_tile.dart';
import '../widgets/forum_access_dialog.dart';
import '../widgets/forum_search_bar.dart';
import '../widgets/featured_forum_item.dart';
import '../../../shared/widgets/bottom_nav_bar.dart';
import '../../../shared/widgets/loading_widget.dart';


class ForumHomeScreen extends ConsumerWidget {
  const ForumHomeScreen({super.key});

  Future<void> _handleJoinForum(BuildContext context, WidgetRef ref, Forum forum) async {
    try {
      // Set the joining state
      ref.read(joiningForumProvider.notifier).state = forum.id;

      if (forum.isPrivate) {
        final accessCode = await showDialog<String>(
          context: context,
          builder: (context) => const ForumAccessDialog(),
        );

        if (accessCode == null) {
          // User cancelled, reset joining state
          ref.read(joiningForumProvider.notifier).state = null;
          return;
        }

        await ref.read(forumRepositoryProvider).joinForum(forum.id, accessCode: accessCode);
      } else {
        await ref.read(forumRepositoryProvider).joinForum(forum.id);
      }

      // Reset joining state
      ref.read(joiningForumProvider.notifier).state = null;

      // Refresh all forum lists
      await Future.wait([
        ref.refresh(createdForumsProvider.future),
        ref.refresh(joinedForumsProvider.future),
        ref.refresh(allForumsProvider.future),
      ]);

      // Navigate to forum chat
      if (context.mounted) {
        context.push(
          ForumRoutes.forumChat.replaceFirst(':forumId', forum.id),
        );
      }
    } catch (e) {
      // Reset joining state
      ref.read(joiningForumProvider.notifier).state = null;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('already a member')
                  ? 'You are already a member of this forum'
                  : e.toString().contains('Invalid access code')
                      ? 'Invalid access code'
                      : 'Failed to join forum',
            ),
          ),
        );
      }
    }
  }

  Widget _buildForumList(
    BuildContext context,
    AsyncValue<List<Forum>> forums,
    bool showJoinButton,
    String emptyMessage,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final query = ref.watch(forumSearchQueryProvider);
    
    return forums.when(
      data: (forumList) {
        final filteredList = ref.watch(filteredForumsProvider(forumList));
        
        if (filteredList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    query.isEmpty ? Icons.forum_outlined : Icons.search_off_rounded,
                    size: 64,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  query.isEmpty ? emptyMessage : 'No forums found matching "$query"',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(createdForumsProvider.future),
              ref.refresh(joinedForumsProvider.future),
              ref.refresh(allForumsProvider.future),
            ]);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              final forum = filteredList[index];
              final isJoining = ref.watch(joiningForumProvider) == forum.id;

              return ForumListTile(
                forum: forum,
                showJoinButton: showJoinButton,
                isJoining: isJoining,
                onJoinTap: () => _handleJoinForum(context, ref, forum),
                onTap: () => context.push(
                  ForumRoutes.forumChat.replaceFirst(':forumId', forum.id),
                ),
              );
            },
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, stack) => SCompassErrorWidget(
        message: error.toString(),
        onRetry: () {
          ref.invalidate(createdForumsProvider);
          ref.invalidate(joinedForumsProvider);
          ref.invalidate(allForumsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allForums = ref.watch(allForumsProvider);
    final createdForums = ref.watch(createdForumsProvider);
    final joinedForums = ref.watch(joinedForumsProvider);
    final joiningForumId = ref.watch(joiningForumProvider);
    final featuredForums = ref.watch(featuredForumsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              title: Text(
                'Forums',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: theme.colorScheme.background,
              elevation: 0,
              floating: true,
              pinned: true,
              snap: true,
              toolbarHeight: 60,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(68),
                child: Container(
                  color: theme.colorScheme.background,
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: const ForumSearchBar(),
                ),
              ),
            ),
            // Featured Forums Section (Collapsible)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 260,
                child: featuredForums.when(
                  data: (forums) {
                    if (forums.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Featured Forums',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            scrollDirection: Axis.horizontal,
                            itemCount: forums.length,
                            itemBuilder: (context, index) {
                              final forum = forums[index];
                              return FeaturedForumItem(
                                forum: forum,
                                onJoinTap: joiningForumId == forum.id
                                    ? null
                                    : () => _handleJoinForum(context, ref, forum),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: LoadingWidget()),
                  error: (error, stack) => const SizedBox.shrink(),
                ),
              ),
            ),
            // Sticky Tab Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                child: Container(
                  color: theme.colorScheme.background,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TabBar(
                      labelColor: theme.colorScheme.background,
                      unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: theme.colorScheme.onBackground,
                      ),
                      dividerColor: Colors.transparent,
                      labelStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                      ),
                      padding: const EdgeInsets.all(2),
                      labelPadding: EdgeInsets.zero,
                      tabs: const [
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('All'),
                          ),
                        ),
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Joined'),
                          ),
                        ),
                        Tab(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('Created'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _buildForumList(
                context,
                allForums,
                true,
                'No forums found',
                ref,
              ),
              _buildForumList(
                context,
                joinedForums,
                false,
                'You haven\'t joined any forums yet',
                ref,
              ),
              _buildForumList(
                context,
                createdForums,
                false,
                'You haven\'t created any forums yet',
                ref,
              ),
            ],
          ),
        ),
        bottomNavigationBar: const SCompassBottomNavBar(),
      ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyTabBarDelegate({required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => 56.0;

  @override
  double get minExtent => 56.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}