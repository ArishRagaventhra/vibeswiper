import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scompass_07/services/connectivity_service.dart';
import 'package:scompass_07/shared/widgets/error_screens.dart';

class ErrorWrapper extends ConsumerWidget {
  final Widget child;
  final Future<void> Function()? onRetry;
  final String? errorMessage;
  final bool isLoading;
  final Object? error;

  const ErrorWrapper({
    Key? key,
    required this.child,
    this.onRetry,
    this.errorMessage,
    this.isLoading = false,
    this.error,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityStatus = ref.watch(connectivityStatusProvider);

    return connectivityStatus.when(
      data: (hasConnection) {
        if (!hasConnection) {
          return NoInternetScreen(onRetry: onRetry);
        }

        if (error != null) {
          return SomethingWentWrongScreen(
            errorMessage: errorMessage,
            onRetry: onRetry,
          );
        }

        return child;
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }
}
