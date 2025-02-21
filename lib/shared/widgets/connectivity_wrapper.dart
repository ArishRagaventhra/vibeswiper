import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/connectivity_service.dart';
import 'error_screens.dart';

class ConnectivityWrapper extends ConsumerWidget {
  final Widget child;

  const ConnectivityWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityStatus = ref.watch(connectivityStatusProvider);

    return connectivityStatus.when(
      data: (hasConnection) {
        if (!hasConnection) {
          return const NoInternetScreen(
            key: ValueKey('no_internet_screen'),
          );
        }
        return child;
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }
}
