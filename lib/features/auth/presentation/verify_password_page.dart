import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/parse_field_errors.dart';
import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import '../../../shared/layouts/blank_layout.dart';
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
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _passwordError = null;
      _confirmError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(signupControllerProvider.notifier).setPassword(_passwordCtrl.text);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(
            title: 'Registration successful! Welcome to Virdan.',
          );
      // Router redirect transitions to onboarding-server-choice via the
      // requiresServer guard once the auth state flips.
    } catch (e) {
      if (!mounted) return;
      final fieldErrors = tryParseFieldErrors(e);
      if (fieldErrors != null) {
        setState(() {
          _passwordError = fieldErrors['password'];
          _confirmError = fieldErrors['confirmPassword'];
        });
      } else {
        showApiErrorToast(ref, e);
      }
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

    return BlankLayout(
      child: ListView(
        children: [
          GestureDetector(
            onTap: _submitting ? null : () => context.go(Routes.authVerifyOtp),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Icon(LucideIcons.arrowLeft, size: 24, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Set your password',
            style: AppTextStyles.h1.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Make sure it's at least 8 characters.",
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            child: Column(
              children: [
                VInput(
                  controller: _passwordCtrl,
                  label: 'Password',
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: _passwordError,
                  validator: (v) => _passwordError ?? _passwordValidator(v),
                  enabled: !_submitting,
                  onChanged: (_) {
                    if (_confirmCtrl.text.isNotEmpty) {
                      _formKey.currentState?.validate();
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                VInput(
                  controller: _confirmCtrl,
                  label: 'Confirm Password',
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  errorText: _confirmError,
                  validator: (v) {
                    if (_confirmError != null) return _confirmError;
                    if (v == null || v.isEmpty) return 'Please confirm your password.';
                    if (v != _passwordCtrl.text) return 'Passwords do not match.';
                    return null;
                  },
                  enabled: !_submitting,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                VButton(
                  label: 'Complete Registration',
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
    );
  }
}

String? _passwordValidator(String? v) {
  if (v == null || v.isEmpty) return 'Password is required.';
  if (v.length < 8) return 'Password must be at least 8 characters.';
  if (v.length > 20) return 'Password must be at most 20 characters.';
  return null;
}
