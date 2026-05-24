import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/util/avatar_color.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../../../core/widgets/v_input.dart';
import '../data/server_detail_api.dart';
import '../data/server_repository.dart';

class JoinByInvitePage extends ConsumerStatefulWidget {
  const JoinByInvitePage({super.key});

  @override
  ConsumerState<JoinByInvitePage> createState() => _JoinByInvitePageState();
}

class _JoinByInvitePageState extends ConsumerState<JoinByInvitePage> {
  final _code = TextEditingController();
  bool _checking = false;
  bool _joining = false;
  ServerInviteInfo? _preview;
  String? _errorText;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'Invite code is required');
      return;
    }
    setState(() {
      _errorText = null;
      _checking = true;
      _preview = null;
    });
    try {
      final info = await ref.read(serverDetailApiProvider).inviteInfo(code);
      if (!mounted) return;
      setState(() => _preview = info);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = 'Invite not found or expired');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() => _joining = true);
    try {
      await ref.read(serverDetailApiProvider).joinViaInvite(code);
      if (!mounted) return;
      await ref.read(myServersProvider.notifier).fetch(force: true);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(
            title: 'Joined ${_preview?.serverName ?? 'server'}',
          );
      context.go(Routes.appHome);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(title: 'Join via invite', leading: VAppBarLeading.back),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VInput(
                controller: _code,
                label: 'Invite code',
                hint: 'e.g. AB12CD34',
                textInputAction: TextInputAction.search,
                errorText: _errorText,
                onFieldSubmitted: (_) => _check(),
              ),
              const SizedBox(height: AppSpacing.md),
              VButton(
                label: 'Find server',
                loading: _checking,
                loadingLabel: 'Searching...',
                fullWidth: true,
                onPressed: _checking ? null : _check,
              ),
              const SizedBox(height: AppSpacing.xl),
              if (_preview != null) _InvitePreview(preview: _preview!, onJoin: _joining ? null : _join, joining: _joining),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvitePreview extends StatelessWidget {
  const _InvitePreview({required this.preview, required this.onJoin, required this.joining});

  final ServerInviteInfo preview;
  final VoidCallback? onJoin;
  final bool joining;

  @override
  Widget build(BuildContext context) {
    final initial = preview.serverShortName.isNotEmpty
        ? preview.serverShortName.characters.first.toUpperCase()
        : preview.serverName.characters.first.toUpperCase();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: avatarColorFor(preview.serverShortName.isNotEmpty
                  ? preview.serverShortName
                  : preview.serverName),
              borderRadius: BorderRadius.circular(16),
            ),
            child: preview.serverAvatarUrl != null && preview.serverAvatarUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      preview.serverAvatarUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  )
                : Text(
                    initial,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(preview.serverName, style: AppTextStyles.h3, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            '@${preview.serverShortName} · ${formatCount(preview.memberCount)} members',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          if (preview.serverDescription != null && preview.serverDescription!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              preview.serverDescription!,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.4),
            ),
          ],
          const SizedBox(height: 20),
          VButton(
            label: preview.alreadyMember ? 'Already joined' : 'Join server',
            loadingLabel: 'Joining...',
            loading: joining,
            fullWidth: true,
            size: VButtonSize.lg,
            onPressed: preview.alreadyMember ? null : onJoin,
            leading: const Icon(LucideIcons.userPlus, size: 20),
          ),
        ],
      ),
    );
  }
}
