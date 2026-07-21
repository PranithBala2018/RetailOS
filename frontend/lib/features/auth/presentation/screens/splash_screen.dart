import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

/// Renders while `sessionProvider` resolves "Session validation" /
/// "Auto Login" (SPRINT0.md §1) — has no navigation logic of its own,
/// the router's `redirect` moves on as soon as the session settles
/// (see core/router/app_router.dart).
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(sessionProvider);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('RetailOS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            if (sessionState.isLoading) const CircularProgressIndicator(),
            if (sessionState.hasError)
              Text(
                'Unable to reach RetailOS. Check your connection.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}
