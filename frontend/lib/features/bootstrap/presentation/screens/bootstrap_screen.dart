import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/api_health.dart';
import '../providers/health_providers.dart';

/// Sprint 1 has no business modules to route to yet, so this screen exists
/// purely to prove the full stack is wired end-to-end: GoRouter renders
/// it, Riverpod drives its state, Dio calls the FastAPI `/health`
/// endpoint, and the response renders back on screen. It is replaced by
/// the real auth/login flow in Sprint 2.
class BootstrapScreen extends ConsumerWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthState = ref.watch(healthCheckProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('RetailOS')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('RetailOS', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Sprint 1 — infrastructure foundation'),
              const SizedBox(height: 32),
              _HealthStatus(state: healthState),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(healthCheckProvider.notifier).refresh(),
                child: const Text('Recheck API connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthStatus extends StatelessWidget {
  const _HealthStatus({required this.state});

  final AsyncValue<ApiHealth> state;

  @override
  Widget build(BuildContext context) {
    return state.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, _) => Text(
        'API unreachable: $error',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
        textAlign: TextAlign.center,
      ),
      data: (health) => Text('API status: ${health.status} (${health.environment})'),
    );
  }
}
