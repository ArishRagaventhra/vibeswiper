import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/blog_model.dart';
import '../providers/blog_providers.dart';
import '../repositories/blog_repository.dart';

class BlogListScreen extends ConsumerStatefulWidget {
  const BlogListScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BlogListScreen> createState() => _BlogListScreenState();
}

class _BlogListScreenState extends ConsumerState<BlogListScreen> {
  final _scrollController = ScrollController();
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Load initial blogs and fetch categories
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blogListProvider.notifier).loadInitialBlogs();
      _fetchCategories();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      ref.read(blogListProvider.notifier).loadMoreBlogs(category: _selectedCategory);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      // Fetch unique categories from the blog repository
      final categories = await ref.read(blogRepositoryProvider).getUniqueCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  void _onCategorySelected(String? category) {
    setState(() {
      _selectedCategory = category;
    });
    ref.read(blogListProvider.notifier).resetState();
    ref.read(blogListProvider.notifier).loadInitialBlogs(category: category);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(blogListProvider);
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('VibeSwiper Blog'),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/account'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Text(
              'Discover stories and guides',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Category filter tabs
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip(null, 'All'),
                  ..._categories.map((category) => _buildCategoryChip(category, category)),
                ],
              ),
            ),
          ),
          
          // Blog list
          Expanded(
            child: _buildBlogList(state, isSmallScreen),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String? category, String label) {
    final isSelected = _selectedCategory == category;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onSelected: (_) => _onCategorySelected(category),
        backgroundColor: colorScheme.surfaceVariant,
        selectedColor: colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildBlogList(BlogListState state, bool isSmallScreen) {
    if (state.loadingState == BlogLoadingState.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (state.blogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No blogs found in this category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later or try another category',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(blogListProvider.notifier).resetState();
        await ref.read(blogListProvider.notifier).loadInitialBlogs(
          category: _selectedCategory,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: isSmallScreen
            ? _buildMobileLayout(state)
            : _buildDesktopLayout(state),
      ),
    );
  }

  Widget _buildMobileLayout(BlogListState state) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: state.blogs.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.blogs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        return _buildMobileCard(state.blogs[index]);
      },
    );
  }

  Widget _buildDesktopLayout(BlogListState state) {
    return GridView.builder(
      controller: _scrollController,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9, // Shorter, wider cards
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: state.blogs.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.blogs.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        return _buildDesktopCard(state.blogs[index]);
      },
    );
  }

  // Completely redesigned mobile card with simpler layout
  Widget _buildMobileCard(Blog blog) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => context.go('/blogs/${blog.slug}'),
        child: SizedBox(
          height: 120, // Fixed height for consistency
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image section - takes 1/3 of width
              if (blog.featuredImage != null)
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Image.network(
                    blog.featuredImage!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: colorScheme.primaryContainer,
                      child: Center(
                        child: Icon(
                          Icons.image,
                          size: 32,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              
              // Content section - takes 2/3 of width
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category label
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(blog.category).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          blog.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getCategoryColor(blog.category),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 6),
                      
                      // Title
                      Text(
                        blog.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Bottom metadata row
                      const Spacer(),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${blog.readTime}m read',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
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
      ),
    );
  }

  // Desktop card with vertical layout
  Widget _buildDesktopCard(Blog blog) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => context.go('/blogs/${blog.slug}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section - takes about 40% of height
            if (blog.featuredImage != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  blog.featuredImage!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: colorScheme.primaryContainer,
                    child: Center(
                      child: Icon(
                        Icons.image,
                        size: 42,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            
            // Content section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row with category and read time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(blog.category).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            blog.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getCategoryColor(blog.category),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${blog.readTime} min read',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Title
                    Text(
                      blog.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Summary
                    Expanded(
                      child: Text(
                        blog.summary,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    // Author info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: colorScheme.primary,
                          child: Text(
                            blog.authorName[0].toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.onPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          blog.authorName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
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
    );
  }

  Color _getCategoryColor(String category) {
    final colorScheme = Theme.of(context).colorScheme;
    
    switch (category) {
      case 'Adventure':
        return Colors.green.shade700;
      case 'Leisure':
        return Colors.blue.shade600;
      case 'Lifestyle':
        return Colors.purple.shade600;
      case 'Tips':
        return Colors.amber.shade700;
      default:
        return colorScheme.primary;
    }
  }
}
