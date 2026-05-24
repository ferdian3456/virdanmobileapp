import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import 'controllers/signup_controller.dart';

class VerifyOtpPage extends ConsumerStatefulWidget {
  const VerifyOtpPage({super.key});

  @override
  ConsumerState<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends ConsumerState<VerifyOtpPage> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();
  bool _submitting = false;
  bool _resending = false;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await ref.read(signupControllerProvider.notifier).verifyOtp(_otpCtrl.text.trim());
      if (!mounted) return;
      context.push(Routes.authVerifyPassword);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await ref.read(signupControllerProvider.notifier).resendOtp();
      if (!mounted) return;
      ref
          .read(toastControllerProvider.notifier)
          .success(title: 'A new code has been sent');
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(signupControllerProvider);
    final email = session.email ?? '';

    // Guard: nyasar ke page ini tanpa sessionId aktif.
    if (!session.hasSession) {
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
              Text('Enter the verification code', style: AppTextStyles.h1),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "We've sent a 6-digit code to ",
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              Text(email, style: AppTextStyles.bodyStrong),
              const SizedBox(height: AppSpacing.xxl),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    VInput(
                      controller: _otpCtrl,
                      label: 'Verification code',
                      hint: '6-digit code',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Code is required';
                        if (v.length != 6) return 'Code must be 6 digits';
                        return null;
                      },
                      enabled: !_submitting,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    VButton(
                      label: 'Verify',
                      loadingLabel: 'Verifying...',
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
                    "Didn't receive the code? ",
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: (_submitting || _resending) ? null : _resend,
                    child: Text(
                      _resending ? 'Sending...' : 'Resend',
                      style: AppTextStyles.bodyStrong.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Keep haptic available for input if we add focus-on-mount feedback later.
// ignore: unused_element
void _tap() => HapticFeedback.lightImpact();
