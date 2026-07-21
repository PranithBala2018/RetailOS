import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dashboard_shell.dart';
import '../providers/dashboard_providers.dart';

class DashboardShellScreen extends ConsumerWidget {
  const DashboardShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellAsync = ref.watch(dashboardShellProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardShellProvider),
        child: shellAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Center(child: Text('Could not load the dashboard: $error')),
              const SizedBox(height: 16),
              Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(dashboardShellProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (shell) => _DashboardContent(shell: shell),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.shell});

  final DashboardShell shell;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shell.companyName, style: Theme.of(context).textTheme.headlineSmall),
                if (shell.branchName != null) ...[
                  const SizedBox(height: 4),
                  Text(shell.branchName!, style: Theme.of(context).textTheme.bodyLarge),
                ],
                const Divider(height: 24),
                Text('Signed in as ${shell.userFullName}'),
                Text(
                  shell.roleNames.isEmpty ? 'No role assigned' : shell.roleNames.join(', '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('System status', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _StatusTile(label: 'API', status: shell.apiStatus),
        _StatusTile(label: 'Database', status: shell.databaseStatus),
        const SizedBox(height: 8),
        Text('RetailOS v${shell.apiVersion}', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.label, required this.status});

  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isOk = status == 'ok';
    return ListTile(
      leading: Icon(
        isOk ? Icons.check_circle : Icons.error,
        color: isOk ? Colors.green : Theme.of(context).colorScheme.error,
      ),
      title: Text(label),
      trailing: Text(status),
    );
  }
}
