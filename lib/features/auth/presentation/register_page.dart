import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/parse_field_errors.dart';
import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import '../../../shared/layouts/blank_layout.dart';
import 'controllers/signup_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;
  String? _emailError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _emailError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(signupControllerProvider.notifier).start(_emailCtrl.text);
      if (!mounted) return;
      context.push(Routes.authVerifyOtp);
    } catch (e) {
      if (!mounted) return;
      final fieldErrors = tryParseFieldErrors(e);
      if (fieldErrors != null && fieldErrors['email'] != null) {
        setState(() => _emailError = fieldErrors['email']);
      } else {
        showApiErrorToast(ref, e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlankLayout(
      child: ListView(
        children: [
          GestureDetector(
            onTap: _submitting ? null : () => context.go(Routes.authLogin),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Icon(LucideIcons.arrowLeft, size: 24, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "What's your email?",
            style: AppTextStyles.h1.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the email where you can be contacted. No one will see this on your profile.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            child: Column(
              children: [
                VInput(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'johndoe@gmail.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  errorText: _emailError,
                  validator: (v) => _emailError ?? _emailValidator(v),
                  enabled: !_submitting,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                VButton(
                  label: 'Next',
                  loadingLabel: 'Sending...',
                  loading: _submitting,
                  size: VButtonSize.lg,
                  fullWidth: true,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: _submitting ? null : () => context.go(Routes.authLogin),
                child: Text(
                  'Sign In',
                  style: AppTextStyles.captionStrong.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String? _emailValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Email is required';
  if (v.length < 5) return 'Email must be at least 5 characters';
  if (v.length > 255) return 'Email must be at most 255 characters';
  if (!_emailRegex.hasMatch(v.trim())) return 'Invalid email format';
  return null;
}

final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
