import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/blog_list_screen.dart';
import '../screens/blog_detail_screen.dart';

class BlogRoutes {
  static List<RouteBase> getRoutes() {
    return [
      GoRoute(
        path: '/blogs',
        builder: (BuildContext context, GoRouterState state) {
          return const BlogListScreen();
        },
      ),
      GoRoute(
        path: '/blogs/:slug',
        builder: (BuildContext context, GoRouterState state) {
          final slug = state.pathParameters['slug']!;
          return BlogDetailScreen(slug: slug);
        },
      ),
    ];
  }
}
