import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import '../../../shared/layouts/blank_layout.dart';
import '../data/auth_repository.dart';
import 'controllers/login_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(loginControllerProvider).submit(
            email: _emailCtrl.text,
            password: _passwordCtrl.text,
          );
      // Router redirect picks up the new auth state and navigates away.
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to repo-driven errors (network races, refresh failures).
    ref.listen<AsyncValue>(authRepositoryProvider, (_, next) {
      if (next.hasError) showApiErrorToast(ref, next.error!);
    });

    return BlankLayout(
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          Text('Masuk ke Virdan', style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Lanjutkan dengan email dan password kamu.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Form(
            key: _formKey,
            child: Column(
              children: [
                VInput(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'kamu@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  validator: _emailValidator,
                  enabled: !_submitting,
                ),
                const SizedBox(height: AppSpacing.md),
                VInput(
                  controller: _passwordCtrl,
                  label: 'Password',
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  validator: _passwordValidator,
                  enabled: !_submitting,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.xl),
                VButton(
                  label: 'Masuk',
                  loadingLabel: 'Masuk...',
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
                'Belum punya akun? ',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: _submitting ? null : () => context.go(Routes.authRegister),
                child: Text(
                  'Daftar',
                  style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
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
  if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
  if (v.length < 5) return 'Email minimal 5 karakter';
  if (v.length > 255) return 'Email maksimal 255 karakter';
  if (!_emailRegex.hasMatch(v.trim())) return 'Format email tidak valid';
  return null;
}

String? _passwordValidator(String? v) {
  if (v == null || v.isEmpty) return 'Password wajib diisi';
  if (v.length < 5) return 'Password minimal 5 karakter';
  if (v.length > 20) return 'Password maksimal 20 karakter';
  return null;
}

final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
