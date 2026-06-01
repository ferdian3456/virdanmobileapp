import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import '../data/account_api.dart';

enum _ChangeEmailStep { request, confirm }

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
final _otpRegex = RegExp(r'^\d{6}$');

class ChangeEmailPage extends ConsumerStatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  ConsumerState<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends ConsumerState<ChangeEmailPage> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  _ChangeEmailStep _step = _ChangeEmailStep.request;
  bool _processing = false;
  String? _emailError;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _otp.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  bool get _canProceed {
    if (_processing) return false;
    if (_step == _ChangeEmailStep.request) {
      return _emailRegex.hasMatch(_email.text.trim());
    }
    return _otpRegex.hasMatch(_otp.text.trim());
  }

  Future<void> _requestChange() async {
    if (!_canProceed) return;
    setState(() {
      _emailError = null;
      _processing = true;
    });
    try {
      await ref.read(accountApiProvider).requestEmailChange(
            _email.text.trim().toLowerCase(),
          );
      if (!mounted) return;
      ref
          .read(toastControllerProvider.notifier)
          .success(title: 'Code sent to your current email.');
      setState(() => _step = _ChangeEmailStep.confirm);
    } catch (e) {
      if (!mounted) return;
      final mapped = mapException(e);
      setState(() => _emailError = _messageFor(mapped, 'Failed to send code. Try again.'));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _confirmChange() async {
    if (!_canProceed) return;
    setState(() {
      _otpError = null;
      _processing = true;
    });
    try {
      await ref.read(accountApiProvider).confirmEmailChange(_otp.text.trim());
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(title: 'Email updated.');
      context.go(Routes.settings);
    } catch (e) {
      if (!mounted) return;
      final mapped = mapException(e);
      setState(() => _otpError = _messageFor(mapped, 'Invalid code. Try again.'));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  String _messageFor(AppError err, String fallback) {
    if (err is ApiError) return err.message.isNotEmpty ? err.message : fallback;
    if (err is ValidationError) return err.message;
    return fallback;
  }

  void _handleBack() {
    if (_step == _ChangeEmailStep.confirm) {
      setState(() {
        _step = _ChangeEmailStep.request;
        _otp.clear();
        _otpError = null;
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VAppBar(
        title: 'Change Email',
        leading: VAppBarLeading.back,
        onLeadingTap: _handleBack,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: _step == _ChangeEmailStep.request
                    ? _RequestForm(
                        controller: _email,
                        errorText: _emailError,
                        onSubmit: _requestChange,
                      )
                    : _ConfirmForm(
                        controller: _otp,
                        newEmail: _email.text.trim(),
                        errorText: _otpError,
                        onSubmit: _confirmChange,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: VButton(
                label: _step == _ChangeEmailStep.request ? 'Send Code' : 'Confirm',
                loading: _processing,
                loadingLabel:
                    _step == _ChangeEmailStep.request ? 'Sending…' : 'Confirming…',
                fullWidth: true,
                size: VButtonSize.lg,
                onPressed: _canProceed
                    ? (_step == _ChangeEmailStep.request
                        ? _requestChange
                        : _confirmChange)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.controller,
    required this.errorText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "We'll send a 6-digit code to your current email to confirm the change.",
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        VInput(
          controller: controller,
          labelOnTop: true,
          label: 'New email',
          hint: 'Enter your new email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.send,
          onFieldSubmitted: (_) => onSubmit(),
          errorText: errorText,
          autofillHints: const [AutofillHints.email],
        ),
      ],
    );
  }
}

class _ConfirmForm extends StatelessWidget {
  const _ConfirmForm({
    required this.controller,
    required this.newEmail,
    required this.errorText,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String newEmail;
  final String? errorText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            children: [
              const TextSpan(
                text:
                    'We sent a 6-digit code to your current email. Enter it below to confirm changing to ',
              ),
              TextSpan(
                text: newEmail,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        VInput(
          controller: controller,
          labelOnTop: true,
          label: 'Verification code',
          hint: '123456',
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          maxLength: 6,
          errorText: errorText,
        ),
      ],
    );
  }
}
