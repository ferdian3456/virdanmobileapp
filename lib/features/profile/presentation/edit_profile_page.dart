import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/http/dio_client.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/avatar_color.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';
import '../../server/data/server_repository.dart';
import '../data/profile_api.dart';

/// Mirrors Quasar EditProfilePage.vue: per-server identity editor with
/// avatar + display name (nickname) + username + bio + floating Save.
/// Multipart PUT /servers/:serverId/profile.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_.]+$');

  final _fullname = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  String _initialFullname = '';
  String _initialUsername = '';
  String _initialBio = '';
  String? _serverAvatarUrl;
  XFile? _avatarFile;
  String? _usernameError;
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _fullname.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sid = ref.read(myServersProvider).activeServerId;
    if (sid == null) return;
    setState(() => _loading = true);
    try {
      final p = await ref.read(profileApiProvider).meForServer(sid);
      if (!mounted) return;
      setState(() {
        _fullname.text = p.nickname;
        _username.text = p.username;
        _bio.text = p.bio ?? '';
        _serverAvatarUrl = p.avatarUrl;
        _initialFullname = p.nickname;
        _initialUsername = p.username;
        _initialBio = p.bio ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).error(title: 'Failed to load profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasChanges {
    if (_avatarFile != null) return true;
    return _fullname.text.trim() != _initialFullname ||
        _username.text.trim() != _initialUsername ||
        _bio.text.trim() != _initialBio;
  }

  String get _initial {
    final src = _fullname.text.trim().isNotEmpty
        ? _fullname.text.trim()
        : switch (ref.read(authRepositoryProvider)) {
            AsyncData(value: AuthAuthenticated(:final user)) => user.email,
            _ => '?',
          };
    return src.characters.first.toUpperCase();
  }

  void _validateUsername(String v) {
    final next = v.toLowerCase();
    if (_username.text != next) {
      _username.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
    String? err;
    if (next.isEmpty) {
      err = null;
    } else if (!_usernameRegex.hasMatch(next)) {
      err = 'Use only letters, digits, _ or . (no spaces)';
    } else if (next.length < 3) {
      err = 'Must be at least 3 characters';
    }
    if (err != _usernameError) {
      setState(() => _usernameError = err);
    } else {
      setState(() {});
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
      setState(() => _avatarFile = file);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    }
  }

  Future<void> _save() async {
    if (!_hasChanges || _saving) return;
    final sid = ref.read(myServersProvider).activeServerId;
    if (sid == null) {
      ref.read(toastControllerProvider.notifier).error(
            title: 'No active server. Select a server first.',
          );
      return;
    }
    if (_usernameError != null) {
      ref.read(toastControllerProvider.notifier).error(title: _usernameError!);
      return;
    }
    setState(() => _saving = true);
    try {
      final form = FormData.fromMap({
        'nickname': _fullname.text.trim(),
        'username': _username.text.trim().toLowerCase(),
        'bio': _bio.text.trim(),
        if (_avatarFile != null)
          'profileAvatar': await MultipartFile.fromFile(
            _avatarFile!.path,
            filename: _avatarFile!.name,
          ),
      });
      await ref.read(apiDioProvider).put<Map<String, dynamic>>(
            '/servers/$sid/profile',
            data: form,
            options: Options(contentType: 'multipart/form-data'),
          );
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(title: 'Profile updated.');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _Header(onBack: () => context.canPop() ? context.pop() : context.go('/settings')),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        _AvatarSection(
                          avatar: _avatarFile,
                          serverAvatarUrl: _serverAvatarUrl,
                          initial: _initial,
                          seed: _fullname.text,
                          onTap: _pickAvatar,
                        ),
                        _FieldRow(
                          label: 'DISPLAY NAME',
                          counter: '${_fullname.text.length}/30',
                          child: _ThemedInput(
                            controller: _fullname,
                            maxLength: 30,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _save(),
                          ),
                        ),
                        _FieldRow(
                          label: 'USERNAME',
                          counter: '${_username.text.length}/22',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ThemedInput(
                                controller: _username,
                                maxLength: 22,
                                prefix: '@',
                                errorText: _usernameError,
                                onChanged: _validateUsername,
                                onSubmitted: (_) => _save(),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(4, 4, 4, 0),
                                child: Text(
                                  'Letters, digits, _ or . (no spaces). Unique within this server.',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _FieldRow(
                          label: 'BIO',
                          counter: '${_bio.text.length}/150',
                          child: _ThemedInput(
                            controller: _bio,
                            maxLength: 150,
                            maxLines: 3,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
          ),
          if (!_loading)
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: Opacity(
                    opacity: _hasChanges ? 1.0 : 0.4,
                    child: Material(
                      color: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _hasChanges && !_saving ? _save : null,
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
            border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(LucideIcons.chevronLeft, size: 24),
                onPressed: onBack,
                tooltip: 'Back',
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.17,
                      color: Color(0xFF0F172A),
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

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.avatar,
    required this.serverAvatarUrl,
    required this.initial,
    required this.seed,
    required this.onTap,
  });

  final XFile? avatar;
  final String? serverAvatarUrl;
  final String initial;
  final String seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: ClipOval(
              child: SizedBox(
                width: 96,
                height: 96,
                child: avatar != null
                    ? Image.file(File(avatar!.path), fit: BoxFit.cover)
                    : (serverAvatarUrl != null && serverAvatarUrl!.isNotEmpty
                        ? Image.network(
                            serverAvatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallback(),
                          )
                        : _fallback()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Change Profile Photo',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: avatarColorFor(seed.isNotEmpty ? seed : initial),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: -0.72,
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.label,
    required this.child,
    this.counter,
  });

  final String label;
  final Widget child;
  final String? counter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.88,
                      color: AppColors.textSecondary,
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
          ),
          child,
        ],
      ),
    );
  }
}

class _ThemedInput extends StatelessWidget {
  const _ThemedInput({
    required this.controller,
    this.maxLength,
    this.maxLines = 1,
    this.prefix,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final int? maxLength;
  final int maxLines;
  final String? prefix;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        prefixText: prefix,
        prefixStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          color: AppColors.textPrimary,
        ),
        errorText: errorText,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
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
