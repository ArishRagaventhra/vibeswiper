import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/forum.dart';

final forumSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredForumsProvider = Provider.family<List<Forum>, List<Forum>>((ref, forums) {
  final query = ref.watch(forumSearchQueryProvider).toLowerCase();
  
  if (query.isEmpty) return forums;
  
  return forums.where((forum) {
    final name = forum.name.toLowerCase();
    final description = forum.description?.toLowerCase() ?? '';
    
    return name.contains(query) || description.contains(query);
  }).toList();
});
