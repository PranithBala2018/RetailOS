import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/branch_selection_providers.dart';

class BranchSelectionScreen extends ConsumerStatefulWidget {
  const BranchSelectionScreen({super.key});

  @override
  ConsumerState<BranchSelectionScreen> createState() => _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends ConsumerState<BranchSelectionScreen> {
  String? _switchingBranchId;

  Future<void> _selectBranch(String branchId) async {
    setState(() => _switchingBranchId = branchId);

    final result = await ref.read(authRepositoryProvider).switchBranch(branchId);
    if (!mounted) return;

    await result.match(
      (failure) async {
        setState(() => _switchingBranchId = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not switch branch: ${failure.runtimeType}')));
      },
      (_) async {
        await ref.read(sessionProvider.notifier).reloadCurrentUser();
        if (mounted) context.go('/dashboard');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(myBranchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select a branch')),
      body: branchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Could not load branches: $error'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(myBranchesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (branches) {
          if (branches.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No branches are assigned to your account yet. '
                  'Ask a company admin to assign you to a branch.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: branches.length,
            itemBuilder: (context, index) {
              final branch = branches[index];
              final isSwitching = _switchingBranchId == branch.id;
              return ListTile(
                leading: const Icon(Icons.store_outlined),
                title: Text(branch.name),
                subtitle: Text(branch.code),
                trailing: isSwitching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _switchingBranchId != null ? null : () => _selectBranch(branch.id),
              );
            },
          );
        },
      ),
    );
  }
}
