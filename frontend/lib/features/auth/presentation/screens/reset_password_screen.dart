import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/responsive_form_scaffold.dart';
import '../providers/auth_providers.dart';

/// Reached via "I already have a reset code" from the Forgot Password
/// screen. No email-delivery channel exists yet (see auth/service.py's
/// Known Issues note), so there is no deep-link entry point today — this
/// screen exists so the reset flow is otherwise complete end-to-end.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(
          token: _tokenController.text.trim(),
          newPassword: _newPasswordController.text,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    result.match((failure) => setState(() => _errorMessage = _messageFor(failure)), (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset. Please sign in with your new password.')),
      );
      context.go('/login');
    });
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
    return ResponsiveFormScaffold(
      title: 'Reset password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: 'Reset code'),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Reset code is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (value) => (value == null || value.length < 8)
                  ? 'Password must be at least 8 characters'
                  : null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Reset password'),
            ),
          ],
        ),
      ),
    );
  }
}
