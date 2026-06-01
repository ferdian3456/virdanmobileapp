import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/parse_field_errors.dart';
import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/router/routes.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../../server/data/server_api.dart';
import '../../server/data/server_create_draft.dart';
import '../../server/data/server_repository.dart';
import '../data/profile_api.dart';

/// Per-server identity form. Used in two contexts:
/// - `/onboarding/create-server/profile` (legacy 2-step create — kept for
///   parity even though CreateServerPage already collects identity).
/// - `/app/create-server/profile` (in-app identity edit / first-join setup).
class YourProfilePage extends ConsumerStatefulWidget {
  const YourProfilePage({super.key, this.targetServerId});

  final String? targetServerId;

  @override
  ConsumerState<YourProfilePage> createState() => _YourProfilePageState();
}

class _YourProfilePageState extends ConsumerState<YourProfilePage> {
  final _nickname = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  XFile? _avatar;
  List<ProfileHistoryItem> _history = const [];
  bool _loadingHistory = false;
  bool _submitting = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  @override
  void dispose() {
    _nickname.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  String get _avatarLetter {
    if (_nickname.text.isNotEmpty) return _nickname.text.characters.first.toUpperCase();
    final email = switch (ref.read(authRepositoryProvider)) {
      AsyncData(value: AuthAuthenticated(:final user)) => user.email,
      _ => '',
    };
    return email.isNotEmpty ? email.characters.first.toUpperCase() : '?';
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final page = await ref.read(profileApiProvider).history();
      if (!mounted) return;
      setState(() => _history = page.data);
    } catch (_) {
      // History is optional; quietly ignore.
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _copyFromHistory(ProfileHistoryItem item) {
    setState(() {
      _nickname.text = item.nickname;
      _username.text = item.username;
      _bio.text = item.bio ?? '';
    });
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1024,
      );
      if (file == null || !mounted) return;
      setState(() => _avatar = file);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    }
  }

  Future<void> _submit() async {
    if (_nickname.text.trim().length < 3) {
      ref.read(toastControllerProvider.notifier).warning(
            title: 'Nickname must be at least 3 characters',
          );
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(_username.text.trim())) {
      setState(() => _usernameError = 'Only letters, digits, _ and . allowed');
      return;
    }
    setState(() {
      _submitting = true;
      _usernameError = null;
    });

    final nickname = _nickname.text.trim();
    final username = _username.text.trim().toLowerCase();
    final bio = _bio.text.trim();

    try {
      final draft = ref.read(serverCreateDraftProvider);
      final joinTarget = ref.read(joinTargetProvider);

      if (draft != null) {
        // Create-server flow — submit combined multipart.
        final newId = await ref.read(serverApiProvider).createServer(
              name: draft.name,
              shortName: draft.shortName,
              categoryId: draft.categoryId,
              isPrivate: draft.isPrivate,
              description: draft.description,
              nickname: nickname,
              username: username,
              bio: bio,
              serverAvatar: draft.avatarFile,
              profileAvatar: _avatar,
            );
        ref.read(serverCreateDraftProvider.notifier).clear();
        await ref.read(myServersProvider.notifier).fetch(force: true);
        if (!mounted) return;
        ref.read(myServersProvider.notifier).setActive(newId);
        ref.read(toastControllerProvider.notifier).success(
              title: 'Server created successfully',
            );
        context.go(Routes.appHome);
      } else if (joinTarget != null) {
        // Join-flow — multipart join with per-server identity.
        await ref.read(serverApiProvider).joinWithProfile(
              serverId: joinTarget.serverId,
              nickname: nickname,
              username: username,
              bio: bio,
              profileAvatar: _avatar,
            );
        ref.read(joinTargetProvider.notifier).clear();
        await ref.read(myServersProvider.notifier).fetch(force: true);
        if (!mounted) return;
        ref.read(myServersProvider.notifier).setActive(joinTarget.serverId);
        ref.read(toastControllerProvider.notifier).success(
              title: 'Joined ${joinTarget.serverName}',
            );
        context.go(Routes.appHome);
      } else {
        // Edit existing per-server profile (PUT /servers/:id/profile).
        final serverId =
            widget.targetServerId ?? ref.read(myServersProvider).activeServerId;
        if (serverId == null) {
          ref.read(toastControllerProvider.notifier).warning(
                title: 'No active server',
                caption: 'Join a server first.',
              );
          return;
        }
        await ref.read(profileApiProvider).upsert(
              serverId: serverId,
              nickname: nickname,
              username: username,
              bio: bio,
            );
        if (!mounted) return;
        ref.read(toastControllerProvider.notifier).success(title: 'Profile saved');
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      final errs = tryParseFieldErrors(e);
      if (errs != null && errs['username'] != null) {
        setState(() => _usernameError = errs['username']);
      } else {
        showApiErrorToast(ref, e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final letter = _avatarLetter;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: VAppBar(title: 'Your Profile', onLeadingTap: () => context.pop()),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AvatarUploader(
                    avatar: _avatar,
                    letter: letter,
                    onTap: _pickAvatar,
                  ),
                  const SizedBox(height: 24),
                  if (_history.isNotEmpty) ...[
                    _FieldLabel(label: 'PROFILE', optionalTag: true),
                    _HistoryPicker(
                      items: _history,
                      loading: _loadingHistory,
                      onPick: _copyFromHistory,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pick a profile from another server to copy',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _FieldLabel(
                    label: 'NICKNAME',
                    required: true,
                    counter: '${_nickname.text.length}/50',
                  ),
                  _Field(
                    controller: _nickname,
                    hint: 'How you appear on this server',
                    maxLength: 50,
                    onChanged: (_) => setState(() {}),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'How other members see you',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel(
                    label: 'USERNAME',
                    required: true,
                    counter: '${_username.text.length}/22',
                  ),
                  _Field(
                    controller: _username,
                    hint: 'yourusername',
                    maxLength: 22,
                    prefix: '@',
                    errorText: _usernameError,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                    ],
                    onChanged: (_) => setState(() => _usernameError = null),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      'Letters, digits, underscores, dots. No spaces. Unique per server.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel(
                    label: 'BIO',
                    optionalTag: true,
                    counter: '${_bio.text.length}/150',
                  ),
                  _Field(
                    controller: _bio,
                    hint: 'Tell us a bit about yourself...',
                    maxLength: 150,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
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
                label: 'Save Profile',
                loadingLabel: 'Saving...',
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
}


class _AvatarUploader extends StatelessWidget {
  const _AvatarUploader({
    required this.avatar,
    required this.letter,
    required this.onTap,
  });

  final XFile? avatar;
  final String letter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 96,
              height: 96,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: avatarColorFor(letter),
                shape: BoxShape.circle,
              ),
              child: avatar == null
                  ? Center(
                      child: Text(
                        letter,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Image.file(File(avatar!.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Profile Photo',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'PNG / JPG, max 5MB',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.textTertiary,
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

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.errorText,
    this.onChanged,
    this.inputFormatters,
    this.prefix,
  });

  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefix,
        prefixStyle: AppTextStyles.body,
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
      ),
    );
  }
}

class _HistoryPicker extends StatelessWidget {
  const _HistoryPicker({
    required this.items,
    required this.loading,
    required this.onPick,
  });

  final List<ProfileHistoryItem> items;
  final bool loading;
  final ValueChanged<ProfileHistoryItem> onPick;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondary),
      hint: Text(
        loading ? 'Loading history…' : 'Choose profile…',
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          color: AppColors.textTertiary,
        ),
      ),
      items: items
          .map(
            (i) => DropdownMenuItem<String>(
              value: i.profileId,
              child: Text('${i.nickname}  ·  ${i.serverName}'),
            ),
          )
          .toList(growable: false),
      onChanged: loading
          ? null
          : (id) {
              if (id == null) return;
              final picked = items.firstWhere((e) => e.profileId == id);
              onPick(picked);
            },
      decoration: InputDecoration(
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
