import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/blog_model.dart';
import '../repositories/blog_repository.dart';

// Blog loading state
enum BlogLoadingState {
  initial,
  loading,
  loaded,
  error,
}

// Blog list state
class BlogListState {
  final List<Blog> blogs;
  final BlogLoadingState loadingState;
  final String? errorMessage;
  final bool hasMore;
  final int currentPage;

  BlogListState({
    required this.blogs,
    required this.loadingState,
    this.errorMessage,
    required this.hasMore,
    required this.currentPage,
  });

  BlogListState copyWith({
    List<Blog>? blogs,
    BlogLoadingState? loadingState,
    String? errorMessage,
    bool? hasMore,
    int? currentPage,
  }) {
    return BlogListState(
      blogs: blogs ?? this.blogs,
      loadingState: loadingState ?? this.loadingState,
      errorMessage: errorMessage,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

// Blog list notifier
class BlogListNotifier extends StateNotifier<BlogListState> {
  final BlogRepository _repository;
  static const int _pageSize = 10;

  BlogListNotifier(this._repository)
      : super(BlogListState(
          blogs: [],
          loadingState: BlogLoadingState.initial,
          hasMore: true,
          currentPage: 0,
        ));

  Future<void> loadInitialBlogs({String? category}) async {
    if (state.loadingState == BlogLoadingState.loading) return;

    state = state.copyWith(
      loadingState: BlogLoadingState.loading,
      errorMessage: null,
    );

    try {
      final blogs = await _repository.getAllBlogs(
        limit: _pageSize,
        offset: 0,
        category: category,
      );

      state = state.copyWith(
        blogs: blogs,
        loadingState: BlogLoadingState.loaded,
        hasMore: blogs.length >= _pageSize,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(
        loadingState: BlogLoadingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> loadMoreBlogs({String? category}) async {
    if (state.loadingState == BlogLoadingState.loading || !state.hasMore) return;

    state = state.copyWith(
      loadingState: BlogLoadingState.loading,
      errorMessage: null,
    );

    try {
      final newBlogs = await _repository.getAllBlogs(
        limit: _pageSize,
        offset: state.currentPage * _pageSize,
        category: category,
      );

      state = state.copyWith(
        blogs: [...state.blogs, ...newBlogs],
        loadingState: BlogLoadingState.loaded,
        hasMore: newBlogs.length >= _pageSize,
        currentPage: state.currentPage + 1,
      );
    } catch (e) {
      state = state.copyWith(
        loadingState: BlogLoadingState.error,
        errorMessage: e.toString(),
      );
    }
  }

  void resetState() {
    state = BlogListState(
      blogs: [],
      loadingState: BlogLoadingState.initial,
      hasMore: true,
      currentPage: 0,
    );
  }
}

// Blog list provider
final blogListProvider =
    StateNotifierProvider<BlogListNotifier, BlogListState>((ref) {
  final repository = ref.watch(blogRepositoryProvider);
  return BlogListNotifier(repository);
});

// Blog detail provider - gets blog by slug
final blogDetailProvider = FutureProvider.family<Blog, String>((ref, slug) async {
  final repository = ref.watch(blogRepositoryProvider);
  return repository.getBlogBySlug(slug);
});

// Blog search provider
final blogSearchProvider = FutureProvider.family<List<Blog>, String>((ref, query) async {
  if (query.isEmpty) return [];
  
  final repository = ref.watch(blogRepositoryProvider);
  return repository.searchBlogs(query);
});
