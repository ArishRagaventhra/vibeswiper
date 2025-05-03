import 'package:flutter/foundation.dart';

class Blog {
  final String id;
  final String title;
  final String slug;
  final String content;
  final String summary;
  final String? featuredImage;
  final String? authorId;
  final String authorName;
  final String category;
  final List<String> keywords;
  final int readTime;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Blog({
    required this.id,
    required this.title,
    required this.slug,
    required this.content,
    required this.summary,
    this.featuredImage,
    this.authorId,
    required this.authorName,
    required this.category,
    required this.keywords,
    required this.readTime,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Blog.fromJson(Map<String, dynamic> json) {
    return Blog(
      id: json['id'] as String,
      title: json['title'] as String,
      slug: json['slug'] as String,
      content: json['content'] as String,
      summary: json['summary'] as String,
      featuredImage: json['featured_image'] as String?,
      authorId: json['author'] as String?,
      authorName: json['author_name'] as String,
      category: json['category'] as String,
      keywords: List<String>.from(json['keywords'] ?? []),
      readTime: json['read_time'] as int,
      publishedAt: DateTime.parse(json['published_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'content': content,
      'summary': summary,
      'featured_image': featuredImage,
      'author': authorId,
      'author_name': authorName,
      'category': category,
      'keywords': keywords,
      'read_time': readTime,
      'published_at': publishedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Blog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
