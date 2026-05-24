import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/parse_field_errors.dart';
import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import '../../../shared/layouts/blank_layout.dart';
import '../data/auth_repository.dart';
import 'controllers/login_controller.dart';
import 'controllers/signup_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _submitting = false;
  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkResume());
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _checkResume() async {
    final step = await ref.read(signupControllerProvider.notifier).probePendingStep();
    if (!mounted || step == null) return;
    final cont = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ResumeRegistrationDialog(),
    );
    if (!mounted) return;
    if (cont == true) {
      switch (step) {
        case SignupStep.startSignup:
          context.push(Routes.authVerifyOtp);
        case SignupStep.otpVerified:
          context.push(Routes.authVerifyPassword);
      }
    } else {
      await ref.read(signupControllerProvider.notifier).reset();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      await ref.read(loginControllerProvider).submit(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(title: 'Login successful');
    } catch (e) {
      if (!mounted) return;
      final fieldErrors = tryParseFieldErrors(e);
      if (fieldErrors != null) {
        setState(() {
          _emailError = fieldErrors['email'];
          _passwordError = fieldErrors['password'];
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
    return BlankLayout(
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Welcome To Virdan',
            style: AppTextStyles.h1.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Good to see you. Enter your email and password to continue.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            child: Column(
              children: [
                VInput(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  errorText: _emailError,
                  validator: (v) => _emailError ?? _emailValidator(v),
                  enabled: !_submitting,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                ),
                const SizedBox(height: AppSpacing.md),
                VInput(
                  controller: _passwordCtrl,
                  focusNode: _passwordFocus,
                  label: 'Password',
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  errorText: _passwordError,
                  validator: (v) => _passwordError ?? _passwordValidator(v),
                  enabled: !_submitting,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                VButton(
                  label: 'Sign In',
                  loadingLabel: 'Signing in...',
                  loading: _submitting,
                  size: VButtonSize.lg,
                  fullWidth: true,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Social logins: backend support pending. Placeholder kept commented
          // to mirror Quasar layout when BE-side OAuth lands.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: _submitting ? null : () => context.go(Routes.authRegister),
                child: Text(
                  'Sign Up',
                  style: AppTextStyles.captionStrong.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          // React to repo-driven errors (network races during refresh).
          Consumer(builder: (_, ref, _) {
            ref.listen<AsyncValue>(authRepositoryProvider, (_, next) {
              if (next.hasError) showApiErrorToast(ref, next.error!);
            });
            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }
}

class _ResumeRegistrationDialog extends StatelessWidget {
  const _ResumeRegistrationDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      title: const Text('Resume Registration'),
      content: const Text(
        'You have an unfinished registration. Would you like to continue where you left off?',
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: VButton(
                label: 'No',
                variant: VButtonVariant.secondary,
                onPressed: () => Navigator.pop(context, false),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: VButton(
                label: 'Yes',
                onPressed: () => Navigator.pop(context, true),
              ),
            ),
          ],
        ),
      ],
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

String? _passwordValidator(String? v) {
  if (v == null || v.isEmpty) return 'Password is required';
  return null;
}

final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
