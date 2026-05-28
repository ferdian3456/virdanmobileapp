import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import '../data/account_api.dart';

enum _ChangePasswordStep { verify, set }

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  _ChangePasswordStep _step = _ChangePasswordStep.verify;
  bool _processing = false;
  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    _current.addListener(() => setState(() {}));
    _next.addListener(() => setState(() {}));
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ruleLength => _next.text.length >= 8;
  bool get _ruleMatch =>
      _next.text.isNotEmpty && _next.text == _confirm.text;

  bool get _canProceed {
    if (_processing) return false;
    if (_step == _ChangePasswordStep.verify) {
      return _current.text.isNotEmpty;
    }
    return _ruleLength && _ruleMatch;
  }

  Future<void> _verifyCurrent() async {
    if (!_canProceed) return;
    setState(() {
      _currentError = null;
      _processing = true;
    });
    try {
      await ref.read(accountApiProvider).verifyCurrentPassword(_current.text);
      if (!mounted) return;
      setState(() => _step = _ChangePasswordStep.set);
    } catch (e) {
      if (!mounted) return;
      final mapped = mapException(e);
      setState(() => _currentError =
          _messageFor(mapped, 'Current password is incorrect.'));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_canProceed) return;
    setState(() {
      _newError = null;
      _confirmError = null;
    });
    if (_next.text == _current.text) {
      setState(() =>
          _newError = 'New password must differ from current password.');
      return;
    }
    setState(() => _processing = true);
    try {
      await ref.read(accountApiProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      ref
          .read(toastControllerProvider.notifier)
          .success(title: 'Password updated.');
      context.go(Routes.settings);
    } catch (e) {
      if (!mounted) return;
      final mapped = mapException(e);
      if (mapped is ApiError && mapped.param == 'currentPassword') {
        setState(() {
          _newError = null;
          _currentError = mapped.message;
          _step = _ChangePasswordStep.verify;
        });
      } else {
        setState(() => _newError =
            _messageFor(mapped, 'Failed to update password. Try again.'));
      }
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
    if (_step == _ChangePasswordStep.set) {
      setState(() {
        _step = _ChangePasswordStep.verify;
        _next.clear();
        _confirm.clear();
        _newError = null;
        _confirmError = null;
      });
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.settings);
    }
  }

  void _forgotPassword() {
    ref
        .read(toastControllerProvider.notifier)
        .info(title: 'Password reset flow is coming soon.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: VAppBar(
        title: 'Change Password',
        leading: VAppBarLeading.back,
        onLeadingTap: _handleBack,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: _step == _ChangePasswordStep.verify
                    ? _VerifyForm(
                        controller: _current,
                        errorText: _currentError,
                        onSubmit: _verifyCurrent,
                        onForgot: _forgotPassword,
                      )
                    : _SetForm(
                        nextCtl: _next,
                        confirmCtl: _confirm,
                        newError: _newError,
                        confirmError: _confirmError,
                        ruleLength: _ruleLength,
                        ruleMatch: _ruleMatch,
                        onSubmit: _updatePassword,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: VButton(
                label: _step == _ChangePasswordStep.verify
                    ? 'Continue'
                    : 'Update Password',
                loading: _processing,
                loadingLabel: _step == _ChangePasswordStep.verify
                    ? 'Verifying…'
                    : 'Updating…',
                fullWidth: true,
                size: VButtonSize.lg,
                onPressed: _canProceed
                    ? (_step == _ChangePasswordStep.verify
                        ? _verifyCurrent
                        : _updatePassword)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifyForm extends StatelessWidget {
  const _VerifyForm({
    required this.controller,
    required this.errorText,
    required this.onSubmit,
    required this.onForgot,
  });

  final TextEditingController controller;
  final String? errorText;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'For your security, please confirm your current password before setting a new one.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        VInput(
          controller: controller,
          label: 'Current password',
          hint: 'Enter your current password',
          obscure: true,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => onSubmit(),
          errorText: errorText,
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onForgot,
          child: const Text(
            'Forgot password?',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SetForm extends StatelessWidget {
  const _SetForm({
    required this.nextCtl,
    required this.confirmCtl,
    required this.newError,
    required this.confirmError,
    required this.ruleLength,
    required this.ruleMatch,
    required this.onSubmit,
  });

  final TextEditingController nextCtl;
  final TextEditingController confirmCtl;
  final String? newError;
  final String? confirmError;
  final bool ruleLength;
  final bool ruleMatch;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Make it at least 8 characters. Choose a password you don't use anywhere else.",
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        VInput(
          controller: nextCtl,
          label: 'New password',
          hint: 'Enter your new password',
          obscure: true,
          textInputAction: TextInputAction.next,
          errorText: newError,
        ),
        const SizedBox(height: 12),
        VInput(
          controller: confirmCtl,
          label: 'Confirm new password',
          hint: 'Re-enter your new password',
          obscure: true,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => onSubmit(),
          errorText: confirmError,
        ),
        const SizedBox(height: 16),
        _Rule(ok: ruleLength, label: 'At least 8 characters'),
        const SizedBox(height: 6),
        _Rule(ok: ruleMatch, label: 'Passwords match'),
      ],
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF10B981) : AppColors.textSecondary;
    return Row(
      children: [
        Icon(
          ok ? LucideIcons.check : LucideIcons.circle,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}
