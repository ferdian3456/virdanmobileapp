import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import '../data/server_detail_api.dart';
import '../data/server_repository.dart';

class EditServerSettingsPage extends ConsumerStatefulWidget {
  const EditServerSettingsPage({super.key, required this.serverId});

  final String serverId;

  @override
  ConsumerState<EditServerSettingsPage> createState() => _EditServerSettingsPageState();
}

class _EditServerSettingsPageState extends ConsumerState<EditServerSettingsPage> {
  ServerDetail? _server;
  bool _loading = false;
  bool _saving = false;
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _description = TextEditingController();
  bool _isPrivate = false;
  final _picker = ImagePicker();
  XFile? _avatar;
  XFile? _banner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _name.dispose();
    _shortName.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await ref.read(serverDetailApiProvider).getById(widget.serverId);
      if (!mounted) return;
      setState(() {
        _server = s;
        _name.text = s.name;
        _shortName.text = s.shortName;
        _description.text = s.description ?? '';
        _isPrivate = s.isPrivate;
      });
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e, onRetry: _load);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _avatar = file);
  }

  Future<void> _pickBanner() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file != null && mounted) setState(() => _banner = file);
  }

  Future<void> _save() async {
    final s = _server;
    if (s == null) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(serverDetailApiProvider);
      final futures = <Future<void>>[];
      if (_name.text.trim() != s.name) {
        futures.add(api.updateName(s.id, _name.text.trim()));
      }
      if (_shortName.text.trim() != s.shortName) {
        futures.add(api.updateShortName(s.id, _shortName.text.trim()));
      }
      if (_description.text.trim() != (s.description ?? '')) {
        futures.add(api.updateDescription(s.id, _description.text.trim()));
      }
      if (_isPrivate != s.isPrivate) {
        futures.add(api.updateSettings(s.id, isPrivate: _isPrivate));
      }
      if (_avatar != null) {
        futures.add(api.updateAvatar(s.id, _avatar!));
      }
      if (_banner != null) {
        futures.add(api.updateBanner(s.id, _banner!));
      }
      await Future.wait(futures);
      if (!mounted) return;
      await ref.read(myServersProvider.notifier).fetch(force: true);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(title: 'Settings saved');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _generateInvite() async {
    try {
      final res = await ref.read(serverDetailApiProvider).createInvite(widget.serverId);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(
            title: 'Invite code created',
            caption: res.code,
          );
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    }
  }

  Widget _bannerPlaceholder() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0056CC), Color(0xFF007BFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SizedBox.expand(),
    );
  }

  Widget _bannerPreview() {
    if (_banner != null) {
      return Image.file(File(_banner!.path), fit: BoxFit.cover);
    }
    final url = _server?.bannerUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _bannerPlaceholder(),
      );
    }
    return _bannerPlaceholder();
  }

  Widget _avatarFallback(double size) {
    final s = _server;
    final seed = (s != null && s.shortName.isNotEmpty)
        ? s.shortName
        : (s?.name ?? '?');
    return Container(
      width: size,
      height: size,
      color: avatarColorFor(seed),
      alignment: Alignment.center,
      child: Text(
        seed.isNotEmpty ? seed[0].toUpperCase() : '?',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size * 0.4,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _avatarPreview() {
    const size = 64.0;
    Widget inner;
    if (_avatar != null) {
      inner = Image.file(File(_avatar!.path),
          width: size, height: size, fit: BoxFit.cover);
    } else {
      final url = _server?.avatarUrl;
      if (url != null && url.isNotEmpty) {
        inner = Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _avatarFallback(size),
        );
      } else {
        inner = _avatarFallback(size);
      }
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipOval(child: inner),
    );
  }

  Widget _editBadge() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: const Icon(LucideIcons.camera, size: 14, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const VAppBar(title: 'Server settings', leading: VAppBarLeading.back),
      body: _loading && _server == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      children: [
                        _SectionCard(
                  title: 'Appearance',
                  children: [
                    GestureDetector(
                      onTap: _pickBanner,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Stack(
                          children: [
                            SizedBox(
                              height: 110,
                              width: double.infinity,
                              child: _bannerPreview(),
                            ),
                            Positioned(right: 8, bottom: 8, child: _editBadge()),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickAvatar,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _avatarPreview(),
                              Positioned(right: -4, bottom: -4, child: _editBadge()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Tap the banner or icon to change your server images.',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                _SectionCard(
                  title: 'General',
                  children: [
                    VInput(controller: _name, label: 'Name', maxLength: 40),
                    const SizedBox(height: 12),
                    VInput(controller: _shortName, label: 'Short name', maxLength: 10),
                    const SizedBox(height: 12),
                    VInput(
                      controller: _description,
                      label: 'Description',
                      maxLength: 500,
                      maxLines: 3,
                    ),
                  ],
                ),
                _SectionCard(
                  title: 'Privacy',
                  children: [
                    SwitchListTile.adaptive(
                      value: _isPrivate,
                      onChanged: (v) => setState(() => _isPrivate = v),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                      title: const Text('Private server',
                          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        _isPrivate
                            ? 'Invite only. Not visible in search.'
                            : 'Visible in global search.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                _SectionCard(
                  title: 'Invites',
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.userPlus, color: AppColors.primary),
                      title: const Text('Create invite link',
                          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500)),
                      trailing: const Icon(LucideIcons.chevronRight, size: 18),
                      onTap: _generateInvite,
                    ),
                  ],
                ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: VButton(
                      label: 'Save changes',
                      loading: _saving,
                      loadingLabel: 'Saving...',
                      fullWidth: true,
                      size: VButtonSize.lg,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.72,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
