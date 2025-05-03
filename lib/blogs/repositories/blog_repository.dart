import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blog_model.dart';

class BlogRepository {
  final SupabaseClient _client;

  BlogRepository({required SupabaseClient client}) : _client = client;

  // Get all blogs with pagination
  Future<List<Blog>> getAllBlogs({
    required int limit,
    required int offset,
    String? category,
  }) async {
    try {
      var query = _client
          .from('blogs')
          .select();

      if (category != null && category.isNotEmpty) {
        query = query.filter('category', 'eq', category);
      }

      final response = await query
          .order('published_at', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);
      
      return response.map((json) => Blog.fromJson(json)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting blogs: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Get a blog by slug
  Future<Blog> getBlogBySlug(String slug) async {
    try {
      final response = await _client
          .from('blogs')
          .select()
          .filter('slug', 'eq', slug)
          .single();

      return Blog.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('Error getting blog by slug: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Create a new blog
  Future<Blog> createBlog(Blog blog) async {
    try {
      final response = await _client
          .from('blogs')
          .insert(blog.toJson())
          .select()
          .single();

      return Blog.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('Error creating blog: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Update an existing blog
  Future<Blog> updateBlog(Blog blog) async {
    try {
      final response = await _client
          .from('blogs')
          .update(blog.toJson())
          .filter('id', 'eq', blog.id)
          .select()
          .single();

      return Blog.fromJson(response);
    } catch (e, stackTrace) {
      debugPrint('Error updating blog: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Delete a blog
  Future<void> deleteBlog(String id) async {
    try {
      await _client
          .from('blogs')
          .delete()
          .filter('id', 'eq', id);
    } catch (e, stackTrace) {
      debugPrint('Error deleting blog: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // Search blogs by title or content
  Future<List<Blog>> searchBlogs(String query) async {
    try {
      final response = await _client
          .from('blogs')
          .select()
          .or('title.ilike.%$query%,content.ilike.%$query%')
          .order('published_at', ascending: false);

      return response.map((json) => Blog.fromJson(json)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error searching blogs: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Gets unique categories from the blogs table
  Future<List<String>> getUniqueCategories() async {
    try {
      final response = await _client
          .from('blogs')
          .select('category')
          .order('category');
      
      // Extract unique categories
      final categoriesSet = <String>{};
      for (final item in response) {
        final category = item['category'] as String;
        if (category.isNotEmpty) {
          categoriesSet.add(category);
        }
      }
      
      return categoriesSet.toList();
    } catch (e, stackTrace) {
      debugPrint('Error fetching categories: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }
}

// Provider for BlogRepository
final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  final supabase = Supabase.instance.client;
  return BlogRepository(client: supabase);
});
