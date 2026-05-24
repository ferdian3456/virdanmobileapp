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
import '../data/server_api.dart';
import '../data/server_repository.dart';
import '../domain/server.dart';

class CreateServerPage extends ConsumerStatefulWidget {
  const CreateServerPage({super.key});

  @override
  ConsumerState<CreateServerPage> createState() => _CreateServerPageState();
}

class _CreateServerPageState extends ConsumerState<CreateServerPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _description = TextEditingController();
  final _nickname = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  int? _categoryId;
  bool _isPrivate = false;

  List<ServerCategory> _categories = const [];
  bool _categoriesLoading = false;
  bool _submitting = false;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  @override
  void dispose() {
    _name.dispose();
    _shortName.dispose();
    _description.dispose();
    _nickname.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      final cats = await ref.read(serverApiProvider).categories();
      if (!mounted) return;
      setState(() => _categories = cats);
    } catch (_) {
      if (!mounted) return;
      ref
          .read(toastControllerProvider.notifier)
          .error(title: 'Failed to load categories.');
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_categoryId == null) {
      setState(() => _fieldErrors = {'categoryId': 'Category is required'});
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(serverApiProvider).createServer(
            name: _name.text.trim(),
            shortName: _shortName.text.trim(),
            categoryId: _categoryId!,
            isPrivate: _isPrivate,
            nickname: _nickname.text.trim(),
            username: _username.text.trim().toLowerCase(),
            description: _description.text.trim(),
            bio: _bio.text.trim(),
          );
      if (!mounted) return;
      await ref.read(myServersProvider.notifier).fetch(force: true);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(
            title: 'Server created successfully',
          );
      context.go(Routes.appHome);
    } catch (e) {
      if (!mounted) return;
      final errs = tryParseFieldErrors(e);
      if (errs != null) {
        setState(() => _fieldErrors = errs);
      } else {
        showApiErrorToast(ref, e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.onboardingServerChoice);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _Header(onBack: _goBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AvatarUploader(onTap: _showAvatarTodoToast),
                    const SizedBox(height: AppSpacing.xxl),

                    _FieldLabel(
                      label: 'SERVER NAME',
                      required: true,
                      counter: '${_name.text.length}/40',
                    ),
                    _ThemedField(
                      controller: _name,
                      hint: 'Enter server name…',
                      maxLength: 40,
                      errorText: _fieldErrors['name'],
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Server name is required' : null,
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _FieldLabel(
                      label: 'SHORT NAME',
                      required: true,
                      counter: '${_shortName.text.length}/10',
                    ),
                    _ThemedField(
                      controller: _shortName,
                      hint: 'Server abbreviation',
                      maxLength: 10,
                      errorText: _fieldErrors['shortName'],
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Short name is required' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        'Server abbreviation for display',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _FieldLabel(label: 'CATEGORY', required: true),
                    _CategorySelect(
                      categories: _categories,
                      loading: _categoriesLoading,
                      value: _categoryId,
                      onChanged: (id) => setState(() => _categoryId = id),
                      errorText: _fieldErrors['categoryId'],
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _FieldLabel(
                      label: 'DESCRIPTION',
                      optionalTag: true,
                      counter: '${_description.text.length}/150',
                    ),
                    _ThemedField(
                      controller: _description,
                      hint: 'Tell us a bit about this server…',
                      maxLength: 150,
                      maxLines: 3,
                      errorText: _fieldErrors['description'],
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _FieldLabel(label: 'PRIVACY'),
                    _PrivacyToggle(
                      isPrivate: _isPrivate,
                      onChanged: (v) => setState(() => _isPrivate = v),
                    ),

                    const SizedBox(height: AppSpacing.xxxl),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE9ECEF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your identity in this server',
                              style: AppTextStyles.bodyStrong),
                          const SizedBox(height: 4),
                          Text(
                            "Choose how you'll be known here. You can use a different name and bio than your other servers.",
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _FieldLabel(
                            label: 'NICKNAME',
                            required: true,
                            counter: '${_nickname.text.length}/50',
                          ),
                          _ThemedField(
                            controller: _nickname,
                            hint: 'How others see you',
                            maxLength: 50,
                            errorText: _fieldErrors['nickname'],
                            validator: (v) {
                              if (v == null || v.trim().length < 3) {
                                return 'Nickname must be at least 3 characters';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _FieldLabel(
                            label: 'USERNAME',
                            required: true,
                            counter: '${_username.text.length}/22',
                          ),
                          _ThemedField(
                            controller: _username,
                            hint: 'unique handle (a-z, 0-9, _ .)',
                            maxLength: 22,
                            errorText: _fieldErrors['username'],
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                            ],
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.length < 3) return 'Username must be at least 3 characters';
                              if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(s)) {
                                return 'Only letters, numbers, _ and . allowed';
                              }
                              return null;
                            },
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _FieldLabel(
                            label: 'BIO',
                            optionalTag: true,
                            counter: '${_bio.text.length}/150',
                          ),
                          _ThemedField(
                            controller: _bio,
                            hint: 'Short bio for this server (optional)',
                            maxLength: 150,
                            maxLines: 2,
                            errorText: _fieldErrors['bio'],
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SafeArea(
              top: false,
              child: VButton(
                label: 'Create Server',
                loadingLabel: 'Creating...',
                loading: _submitting,
                size: VButtonSize.lg,
                fullWidth: true,
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarTodoToast() {
    ref.read(toastControllerProvider.notifier).info(
          title: 'Image upload lands in Phase 4',
        );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onBack,
                    child: const Center(child: Icon(LucideIcons.chevronLeft, size: 24)),
                  ),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Create Server',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 40, height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
    this.required = false,
    this.optionalTag = false,
    this.counter,
  });

  final String label;
  final bool required;
  final bool optionalTag;
  final String? counter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.72,
                  color: Color(0xFF495057),
                ),
                children: [
                  TextSpan(text: label),
                  if (required)
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: AppColors.error),
                    ),
                  if (optionalTag)
                    const TextSpan(
                      text: ' (OPTIONAL)',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (counter != null)
            Text(
              counter!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemedField extends StatelessWidget {
  const _ThemedField({
    required this.controller,
    this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.errorText,
    this.validator,
    this.onChanged,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}

class _CategorySelect extends StatelessWidget {
  const _CategorySelect({
    required this.categories,
    required this.loading,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final List<ServerCategory> categories;
  final bool loading;
  final int? value;
  final ValueChanged<int?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondary),
      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textPrimary),
      hint: Text(
        loading ? 'Loading categories…' : 'Select category…',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          color: AppColors.textTertiary,
        ),
      ),
      items: categories
          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.categoryName)))
          .toList(growable: false),
      onChanged: loading ? null : onChanged,
      decoration: InputDecoration(
        errorText: errorText,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9ECEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.isPrivate, required this.onChanged});

  final bool isPrivate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PrivacyCard(
            active: !isPrivate,
            icon: LucideIcons.globe,
            name: 'Public',
            help: 'Visible in global search',
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PrivacyCard(
            active: isPrivate,
            icon: LucideIcons.lock,
            name: 'Private',
            help: 'Invite only',
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.active,
    required this.icon,
    required this.name,
    required this.help,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String name;
  final String help;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : const Color(0xFF495057);
    return Material(
      color: active ? const Color(0xFFEEF0FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: active ? AppColors.primary : const Color(0xFFE9ECEF),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    help,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: active ? AppColors.primary : const Color(0xFFDEE2E6),
                      width: 1.5,
                    ),
                  ),
                  child: active
                      ? const Icon(LucideIcons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarUploader extends StatelessWidget {
  const _AvatarUploader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(
              color: AppColors.textTertiary,
              width: 1.5,
              style: BorderStyle.solid,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: const SizedBox(
              width: 96,
              height: 96,
              child: Center(
                child: Icon(LucideIcons.image, size: 36, color: AppColors.textTertiary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Server Icon (optional)',
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        const Text(
          'PNG, JPG min 512px — image upload lands in Phase 4',
          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
