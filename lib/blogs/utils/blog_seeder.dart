import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/blog_model.dart';

class BlogSeeder {
  final SupabaseClient _client;
  
  BlogSeeder({required SupabaseClient client}) : _client = client;

  /// Parses the blog content from blog.txt and seeds the database
  Future<void> seedBlogsFromContent(String content) async {
    try {
      final blogs = _parseBlogs(content);
      
      for (final blog in blogs) {
        await _insertBlog(blog);
      }
      
      debugPrint('Successfully seeded ${blogs.length} blogs to the database');
    } catch (e, stackTrace) {
      debugPrint('Error seeding blogs: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Parses the blog text content into Blog objects
  List<Blog> _parseBlogs(String content) {
    final blogs = <Blog>[];
    final sections = content.split('---');
    
    for (var section in sections) {
      if (section.trim().isEmpty) continue;
      
      // Try to extract blog details from the section
      final titleMatch = RegExp(r'## \d+\. (.*?)(?:\r?\n|\$)').firstMatch(section);
      if (titleMatch == null) continue;
      
      final title = titleMatch.group(1)?.trim() ?? 'Untitled Blog';
      
      // Extract keywords
      final keywordsMatch = RegExp(r'\*\*Keywords:\*\* (.*?)(?:\r?\n|\$)').firstMatch(section);
      final keywordsString = keywordsMatch?.group(1) ?? '';
      final keywords = keywordsString
          .split(',')
          .map((keyword) => keyword.trim())
          .where((keyword) => keyword.isNotEmpty)
          .toList();
      
      // Generate a slug from the title
      final slug = _generateSlug(title);
      
      // Determine category from content
      String category = 'Lifestyle';
      if (section.contains('Adventure')) {
        category = 'Adventure';
      } else if (section.contains('Leisure')) {
        category = 'Leisure';
      } else if (section.contains('Tips') || section.contains('Guide')) {
        category = 'Tips';
      }
      
      // Create Blog object
      final blog = Blog(
        id: const Uuid().v4(),
        title: title,
        slug: slug,
        content: section.trim(),
        summary: _extractSummary(section),
        featuredImage: _getCategoryImage(category),
        authorId: null,
        authorName: 'VibeSwiper Team',
        category: category,
        keywords: keywords,
        readTime: _calculateReadTime(section),
        publishedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      blogs.add(blog);
    }
    
    return blogs;
  }
  
  /// Extracts a summary from the blog content
  String _extractSummary(String content) {
    // Try to find the introduction section
    final introMatch = RegExp(r'### Introduction\s+(.*?)(?=###|\$)', dotAll: true).firstMatch(content);
    if (introMatch != null) {
      final intro = introMatch.group(1)?.trim() ?? '';
      // Limit to first 150 characters
      return intro.length > 150 ? '${intro.substring(0, 147)}...' : intro;
    }
    
    // Fallback: take first paragraph
    final paragraphs = content.split('\n\n');
    for (final paragraph in paragraphs) {
      if (paragraph.trim().isNotEmpty && !paragraph.contains('#')) {
        final cleanParagraph = paragraph.replaceAll(RegExp(r'\*\*|\*'), '').trim();
        return cleanParagraph.length > 150 ? '${cleanParagraph.substring(0, 147)}...' : cleanParagraph;
      }
    }
    
    return 'Discover amazing adventures, leisure activities, and lifestyle events with VibeSwiper.';
  }
  
  /// Generates a URL-friendly slug from a title
  String _generateSlug(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }
  
  /// Calculate approximate read time based on content length
  int _calculateReadTime(String content) {
    // Average reading speed: 200-250 words per minute
    final wordCount = content.split(RegExp(r'\s+')).length;
    final minutes = (wordCount / 200).ceil();
    return minutes < 1 ? 1 : minutes;
  }
  
  /// Get a relevant image URL based on category
  String _getCategoryImage(String category) {
    switch (category) {
      case 'Adventure':
        return 'https://images.unsplash.com/photo-1530021356476-0a6375ffe73f?q=80&w=1000';
      case 'Leisure':
        return 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?q=80&w=1000';
      case 'Tips':
        return 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?q=80&w=1000';
      default: // Lifestyle
        return 'https://images.unsplash.com/photo-1511988617509-a57c8a288659?q=80&w=1000';
    }
  }
  
  /// Insert a blog into the database
  Future<void> _insertBlog(Blog blog) async {
    try {
      await _client
          .from('blogs')
          .insert(blog.toJson());
      
      debugPrint('Successfully inserted blog: ${blog.title}');
    } catch (e, stackTrace) {
      debugPrint('Error inserting blog: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
}
