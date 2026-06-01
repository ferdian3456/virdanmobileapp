import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../shared/layouts/blank_layout.dart';
import 'controllers/signup_controller.dart';

class VerifyOtpPage extends ConsumerStatefulWidget {
  const VerifyOtpPage({super.key});

  @override
  ConsumerState<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends ConsumerState<VerifyOtpPage> {
  final List<TextEditingController> _digitCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _digitFocus = List.generate(6, (_) => FocusNode());
  Timer? _ticker;
  String _timeLeft = '';
  bool _expired = false;
  bool _submitting = false;
  bool _resending = false;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _digitFocus.first.requestFocus();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in _digitCtrls) {
      c.dispose();
    }
    for (final f in _digitFocus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _digitCtrls.map((c) => c.text).join();

  void _startTimer() {
    _ticker?.cancel();
    _tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final expiresAt = ref.read(signupControllerProvider).otpExpiresAt;
    if (expiresAt == null || expiresAt == 0) {
      if (!mounted) return;
      setState(() {
        _timeLeft = '';
        _expired = false;
      });
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = expiresAt - now;
    if (!mounted) return;
    if (diff <= 0) {
      setState(() {
        _timeLeft = 'Expired';
        _expired = true;
      });
      _ticker?.cancel();
    } else {
      final m = diff ~/ 60;
      final s = diff % 60;
      setState(() {
        _timeLeft = '$m:${s.toString().padLeft(2, '0')}';
        _expired = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _otpError = null);
    if (_otp.length < 6) {
      setState(() => _otpError = 'Please enter the complete 6-digit code.');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(signupControllerProvider.notifier).verifyOtp(_otp);
      if (!mounted) return;
      context.push(Routes.authVerifyPassword);
    } catch (e) {
      if (!mounted) return;
      final fieldErrors = tryParseFieldErrors(e);
      if (fieldErrors != null && fieldErrors['otp'] != null) {
        setState(() => _otpError = fieldErrors['otp']);
      } else {
        showApiErrorToast(ref, e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _otpError = null;
    });
    try {
      await ref.read(signupControllerProvider.notifier).resendOtp();
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(
            title: 'A new verification code has been sent to your email.',
          );
      for (final c in _digitCtrls) {
        c.clear();
      }
      _startTimer();
      _digitFocus.first.requestFocus();
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _onDigitChanged(int index, String v) {
    if (v.isEmpty) return;
    final digit = v.characters.last;
    if (!RegExp(r'^\d$').hasMatch(digit)) {
      _digitCtrls[index].text = '';
      return;
    }
    _digitCtrls[index].text = digit;
    if (index < 5) {
      _digitFocus[index + 1].requestFocus();
    } else {
      _digitFocus[index].unfocus();
      if (_otp.length == 6) _submit();
    }
  }

  void _onDigitKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _digitCtrls[index].text.isEmpty &&
        index > 0) {
      _digitFocus[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(signupControllerProvider);
    if (!session.hasSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.authRegister);
      });
    }

    return BlankLayout(
      child: ListView(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _submitting ? null : () => context.go(Routes.authRegister),
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Icon(LucideIcons.arrowLeft, size: 24, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Verify OTP',
            style: AppTextStyles.h1.copyWith(fontSize: 30, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "We've sent a verification code to your email. Please enter it below.",
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (_timeLeft.isNotEmpty)
            Text(
              _expired ? 'Code expired. Please try again.' : 'Code expires in $_timeLeft',
              style: AppTextStyles.caption.copyWith(
                color: _expired ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              return Padding(
                padding: EdgeInsets.only(right: i == 5 ? 0 : AppSpacing.sm),
                child: _OtpBox(
                  controller: _digitCtrls[i],
                  focusNode: _digitFocus[i],
                  enabled: !_submitting,
                  onChanged: (v) => _onDigitChanged(i, v),
                  onKey: (event) => _onDigitKey(i, event),
                ),
              );
            }),
          ),
          if (_otpError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _otpError!,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          VButton(
            label: 'Next',
            loadingLabel: 'Verifying...',
            loading: _submitting,
            size: VButtonSize.lg,
            fullWidth: true,
            onPressed: _submitting ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't receive a code? ",
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              GestureDetector(
                onTap: (_submitting || _resending) ? null : _resend,
                child: Text(
                  _resending ? 'Sending...' : 'Resend',
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

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onChanged,
    required this.onKey,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 48,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: onKey,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 1,
          showCursor: true,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontFamily: 'Inter',
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            isCollapsed: false,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
