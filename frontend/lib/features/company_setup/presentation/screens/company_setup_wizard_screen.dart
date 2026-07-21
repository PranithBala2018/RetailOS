import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/repositories/company_setup_repository.dart';
import '../providers/company_setup_providers.dart';

/// Two-step wizard: company profile, then the owner account. A handful
/// of Company fields are deliberately collected here (name, brand,
/// currency, GST) rather than the full set from DATABASE.md — the rest
/// (address, invoice settings, tax defaults, ...) are edited later via
/// company settings, which is out of scope for Sprint 2's screen list.
class CompanySetupWizardScreen extends ConsumerStatefulWidget {
  const CompanySetupWizardScreen({super.key});

  @override
  ConsumerState<CompanySetupWizardScreen> createState() => _CompanySetupWizardScreenState();
}

class _CompanySetupWizardScreenState extends ConsumerState<CompanySetupWizardScreen> {
  final _companyFormKey = GlobalKey<FormState>();
  final _ownerFormKey = GlobalKey<FormState>();

  final _companyNameController = TextEditingController();
  final _brandNameController = TextEditingController();
  final _gstNumberController = TextEditingController();
  String _currency = 'INR';

  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _ownerPasswordController = TextEditingController();

  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const _currencies = ['INR', 'USD', 'EUR', 'GBP', 'AED'];

  @override
  void dispose() {
    _companyNameController.dispose();
    _brandNameController.dispose();
    _gstNumberController.dispose();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    super.dispose();
  }

  void _onStepContinue() {
    if (_currentStep == 0) {
      if (_companyFormKey.currentState!.validate()) {
        setState(() => _currentStep = 1);
      }
      return;
    }
    _submit();
  }

  void _onStepCancel() {
    if (_currentStep == 0) {
      context.pop();
    } else {
      setState(() => _currentStep = 0);
    }
  }

  Future<void> _submit() async {
    if (!_ownerFormKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final repository = ref.read(companySetupRepositoryProvider);
    final result = await repository.signUp(
      CompanySignupParams(
        companyName: _companyNameController.text.trim(),
        brandName: _brandNameController.text.trim(),
        gstNumber: _gstNumberController.text.trim(),
        currency: _currency,
        ownerFullName: _ownerNameController.text.trim(),
        ownerEmail: _ownerEmailController.text.trim(),
        ownerPassword: _ownerPasswordController.text,
      ),
    );

    if (!mounted) return;

    await result.match(
      (failure) async => setState(() {
        _isSubmitting = false;
        _errorMessage = _messageFor(failure);
      }),
      (_) async {
        await ref.read(sessionProvider.notifier).refresh();
      },
    );
  }

  String _messageFor(Failure failure) {
    return failure.when<String>(
      network: (message) => message ?? 'No internet connection. Please try again.',
      server: (message, statusCode) => message ?? 'Something went wrong. Please try again.',
      cache: (message) => message ?? 'Something went wrong. Please try again.',
      validation: (message, fieldErrors) => message,
      conflict: (message) => message ?? 'That email is already registered.',
      auth: (message) => message ?? 'Something went wrong. Please try again.',
      unexpected: (message) => message ?? 'Something went wrong. Please try again.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up your company')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _isSubmitting ? null : _onStepContinue,
        onStepCancel: _isSubmitting ? null : _onStepCancel,
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              FilledButton(
                onPressed: details.onStepContinue,
                child: _isSubmitting && _currentStep == 1
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_currentStep == 0 ? 'Next' : 'Create company'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: details.onStepCancel,
                child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
              ),
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('Company profile'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _companyFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _companyNameController,
                    decoration: const InputDecoration(labelText: 'Company name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _brandNameController,
                    decoration: const InputDecoration(labelText: 'Brand name (optional)'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _gstNumberController,
                    decoration: const InputDecoration(labelText: 'GST number (optional)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
                    items: _currencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) => setState(() => _currency = value ?? _currency),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Owner account'),
            isActive: _currentStep >= 1,
            content: Form(
              key: _ownerFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(labelText: 'Your full name'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ownerEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ownerPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => (value == null || value.length < 8)
                        ? 'Password must be at least 8 characters'
                        : null,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
