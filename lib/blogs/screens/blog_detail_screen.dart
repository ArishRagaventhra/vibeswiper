import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/blog_providers.dart';

class BlogDetailScreen extends ConsumerWidget {
  final String slug;

  const BlogDetailScreen({Key? key, required this.slug}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blogDetailAsync = ref.watch(blogDetailProvider(slug));
    final isSmallScreen = MediaQuery.of(context).size.width < 800;
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Blog'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/blogs'),
          tooltip: 'Back to blogs',
        ),
      ),
      body: blogDetailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Could not load the blog',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                  onPressed: () => ref.refresh(blogDetailProvider(slug)),
                ),
              ],
            ),
          ),
        ),
        data: (blog) {
          return isSmallScreen
              ? _buildMobileLayout(context, blog)
              : _buildDesktopLayout(context, blog);
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, dynamic blog) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured image
          if (blog.featuredImage != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                blog.featuredImage!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: const Center(
                    child: Icon(Icons.image, size: 64),
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category and read time
                Row(
                  children: [
                    Chip(
                      label: Text(
                        blog.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${blog.readTime} min read',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Title
                Text(
                  blog.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                
                const SizedBox(height: 16),
                
                // Author info and date
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        blog.authorName[0].toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          blog.authorName,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          _formatDate(blog.publishedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Content
                Text(
                  blog.content,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    height: 1.7,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Keywords
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: blog.keywords.map<Widget>((keyword) {
                    return Chip(
                      label: Text(
                        keyword,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, dynamic blog) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Featured image
                if (blog.featuredImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 21 / 9,
                      child: Image.network(
                        blog.featuredImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: const Center(
                            child: Icon(Icons.image, size: 84),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Category and read time
                Row(
                  children: [
                    Chip(
                      label: Text(
                        blog.category,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${blog.readTime} min read',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Title
                Text(
                  blog.title,
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                
                const SizedBox(height: 24),
                
                // Author info and date
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        blog.authorName[0].toUpperCase(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          blog.authorName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _formatDate(blog.publishedAt),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Content
                Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Text(
                    blog.content,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      height: 1.8,
                      fontSize: 18,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Keywords
                Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: blog.keywords.map<Widget>((keyword) {
                      return Chip(
                        label: Text(
                          keyword,
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }
}
