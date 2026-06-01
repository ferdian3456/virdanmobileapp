import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../data/server_api.dart';
import '../data/server_create_draft.dart';
import '../domain/server.dart';

/// Step 1 of the create-server flow. Matches Quasar CreateServerPage.vue:
/// server fields only + Next button. Identity (nickname / username / bio /
/// profile avatar) is captured in step 2 (YourProfilePage) which submits the
/// combined multipart payload.
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
  int? _categoryId;
  bool _isPrivate = false;
  XFile? _avatar;

  List<ServerCategory> _categories = const [];
  bool _categoriesLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
    // Hydrate from any previously-saved draft (back-nav from YourProfilePage).
    final draft = ref.read(serverCreateDraftProvider);
    if (draft != null) {
      _name.text = draft.name;
      _shortName.text = draft.shortName;
      _description.text = draft.description;
      _categoryId = draft.categoryId;
      _isPrivate = draft.isPrivate;
      _avatar = draft.avatarFile;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _shortName.dispose();
    _description.dispose();
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

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1024,
      );
      if (file == null || !mounted) return;
      setState(() => _avatar = file);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    }
  }

  Future<void> _openCategoryPicker() async {
    if (_categoriesLoading) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose category',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final c = _categories[i];
                    final active = c.id == _categoryId;
                    return ListTile(
                      title: Text(
                        c.categoryName,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      trailing: active
                          ? const Icon(LucideIcons.check, color: AppColors.primary)
                          : null,
                      onTap: () => Navigator.pop(context, c.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _categoryId = picked);
  }

  void _next() {
    final canSubmit = _name.text.trim().isNotEmpty &&
        _shortName.text.trim().isNotEmpty &&
        _categoryId != null;
    if (!canSubmit) {
      _formKey.currentState?.validate();
      if (_categoryId == null) {
        ref
            .read(toastControllerProvider.notifier)
            .warning(title: 'Pick a category');
      }
      return;
    }
    ref.read(serverCreateDraftProvider.notifier).setDraft(
          ServerCreateDraft(
            name: _name.text.trim(),
            shortName: _shortName.text.trim(),
            categoryId: _categoryId!,
            description: _description.text.trim(),
            isPrivate: _isPrivate,
            avatarPath: _avatar?.path,
            avatarName: _avatar?.name,
          ),
        );

    final loc = GoRouterState.of(context).matchedLocation;
    final target = loc.startsWith('/onboarding')
        ? '/onboarding/create-server/profile'
        : '/app/create-server/profile';
    context.push(target);
  }

  void _goBack() {
    ref.read(serverCreateDraftProvider.notifier).clear();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/onboarding/server-choice');
    }
  }

  String? get _selectedCategoryLabel {
    if (_categoryId == null) return null;
    for (final c in _categories) {
      if (c.id == _categoryId) return c.categoryName;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: VAppBar(title: 'Create Server', onLeadingTap: _goBack),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: _AvatarUploader(
                        avatar: _avatar,
                        onTap: _pickAvatar,
                      ),
                    ),
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Server name is required'
                          : null,
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Short name is required'
                          : null,
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
                    _CategoryPickerField(
                      label: _categoriesLoading
                          ? 'Loading categories…'
                          : (_selectedCategoryLabel ?? 'Select category…'),
                      isPlaceholder: _selectedCategoryLabel == null,
                      onTap: _openCategoryPicker,
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
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: AppSpacing.lg),
                    _FieldLabel(label: 'PRIVACY'),
                    _PrivacyToggle(
                      isPrivate: _isPrivate,
                      onChanged: (v) => setState(() => _isPrivate = v),
                    ),
                    const SizedBox(height: AppSpacing.xxxl),
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
                label: 'Next',
                size: VButtonSize.lg,
                fullWidth: true,
                onPressed: _next,
              ),
            ),
          ),
        ],
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
    this.validator,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
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
      ),
    );
  }
}

class _CategoryPickerField extends StatelessWidget {
  const _CategoryPickerField({
    required this.label,
    required this.isPlaceholder,
    required this.onTap,
  });

  final String label;
  final bool isPlaceholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE9ECEF)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: isPlaceholder
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronDown,
                  size: 18, color: AppColors.textSecondary),
            ],
          ),
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
  const _AvatarUploader({required this.avatar, required this.onTap});

  final XFile? avatar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.textTertiary, width: 1.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: SizedBox(
              width: 96,
              height: 96,
              child: avatar == null
                  ? const Center(
                      child: Icon(LucideIcons.image,
                          size: 36, color: AppColors.textTertiary),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(File(avatar!.path), fit: BoxFit.cover),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Server Icon (optional)',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        const Text(
          'PNG, JPG min 512px',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textTertiary),
        ),
      ],
    );
  }
}
