import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your profile: $error')),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not signed in'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CircleAvatar(
                radius: 32,
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user.fullName,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Text(user.email, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              const _ChangePasswordCard(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.read(sessionProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChangePasswordCard extends ConsumerStatefulWidget {
  const _ChangePasswordCard();

  @override
  ConsumerState<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends ConsumerState<_ChangePasswordCard> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    final result = await ref
        .read(authRepositoryProvider)
        .changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );

    if (!mounted) return;
    result.match(
      (failure) => setState(() {
        _isSubmitting = false;
        _messageIsError = true;
        _message = _messageFor(failure);
      }),
      (_) => setState(() {
        _isSubmitting = false;
        _messageIsError = false;
        _message = 'Password changed';
        _currentPasswordController.clear();
        _newPasswordController.clear();
      }),
    );
  }

  String _messageFor(Failure failure) {
    return failure.when<String>(
      network: (message) => message ?? 'No internet connection. Please try again.',
      server: (message, statusCode) => message ?? 'Something went wrong. Please try again.',
      cache: (message) => message ?? 'Something went wrong. Please try again.',
      validation: (message, fieldErrors) => message,
      conflict: (message) => message ?? 'Something went wrong. Please try again.',
      auth: (message) => message ?? 'Something went wrong. Please try again.',
      unexpected: (message) => message ?? 'Something went wrong. Please try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Change password', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) =>
                    (value == null || value.length < 8) ? 'At least 8 characters' : null,
              ),
              if (_message != null) ...[
                const SizedBox(height: 8),
                Text(
                  _message!,
                  style: TextStyle(
                    color: _messageIsError ? Theme.of(context).colorScheme.error : Colors.green,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
