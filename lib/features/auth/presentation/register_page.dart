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

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(signupControllerProvider.notifier).start(_emailCtrl.text);
      if (!mounted) return;
      context.push(Routes.authVerifyOtp);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlankLayout(
      child: ListView(
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          Text('Buat akun Virdan', style: AppTextStyles.h1),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mulai dengan email kamu — kode OTP akan dikirim untuk verifikasi.',
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
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.email],
                  validator: _emailValidator,
                  enabled: !_submitting,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.xl),
                VButton(
                  label: 'Kirim kode OTP',
                  loadingLabel: 'Mengirim...',
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
                'Sudah punya akun? ',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: _submitting ? null : () => context.go(Routes.authLogin),
                child: Text(
                  'Masuk',
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

final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
