import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import 'controllers/signup_controller.dart';

class VerifyPasswordPage extends ConsumerStatefulWidget {
  const VerifyPasswordPage({super.key});

  @override
  ConsumerState<VerifyPasswordPage> createState() => _VerifyPasswordPageState();
}

class _VerifyPasswordPageState extends ConsumerState<VerifyPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(signupControllerProvider.notifier)
          .setPassword(_passwordCtrl.text);
      // Auth state updated by controller; router redirect handles navigation.
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(signupControllerProvider);
    if (!session.hasSession || !session.otpVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.authRegister);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(leading: VAppBarLeading.back),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ListView(
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('Create a password', style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Between 5 and 20 characters. Keep it safe.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    VInput(
                      controller: _passwordCtrl,
                      label: 'Password',
                      obscure: true,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: _passwordValidator,
                      enabled: !_submitting,
                      onChanged: (_) {
                        // Re-run cross-field validation as user types.
                        _formKey.currentState?.validate();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    VInput(
                      controller: _confirmCtrl,
                      label: 'Confirm password',
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        final p = _passwordValidator(v);
                        if (p != null) return p;
                        if (v != _passwordCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                      enabled: !_submitting,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    VButton(
                      label: 'Complete sign up',
                      loadingLabel: 'Finishing...',
                      loading: _submitting,
                      size: VButtonSize.lg,
                      fullWidth: true,
                      onPressed: _submitting ? null : _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _passwordValidator(String? v) {
  if (v == null || v.isEmpty) return 'Password is required';
  if (v.length < 5) return 'Password must be at least 5 characters';
  if (v.length > 20) return 'Password must be at most 20 characters';
  return null;
}
