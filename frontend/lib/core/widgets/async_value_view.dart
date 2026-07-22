import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Standard loading/error/data rendering for any `AsyncValue`, generalized
/// from the pattern in `dashboard_shell_screen.dart` so every ERP module's
/// list/detail screen renders the same way instead of re-implementing
/// this by hand. The error branch is wrapped in a `ListView` (not
/// `Center` alone) so a `RefreshIndicator` ancestor still works.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.errorPrefix = 'Something went wrong',
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;
  final VoidCallback? onRetry;
  final String errorPrefix;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ListView(
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('$errorPrefix: $error', textAlign: TextAlign.center),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            Center(
              child: FilledButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ],
      ),
      data: (value) => data(context, value),
    );
  }
}
