import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forum.dart';
import '../providers/forum_providers.dart';

final featuredForumsProvider = FutureProvider<List<Forum>>((ref) async {
  final repository = ref.watch(forumRepositoryProvider);
  // For now, we'll use the first 5 public forums as featured
  // You can modify this logic based on your requirements
  final forums = await repository.getPublicForums();
  return forums.take(5).toList();
});
