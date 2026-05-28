import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
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
  bool _deleting = false;
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _description = TextEditingController();
  bool _isPrivate = false;

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

  Future<void> _confirmDelete() async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => AlertDialog.adaptive(
        title: const Text('Delete server?'),
        content: const Text(
          'All posts, comments and members will be gone permanently. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await ref.read(serverDetailApiProvider).delete(widget.serverId);
      if (!mounted) return;
      await ref.read(myServersProvider.notifier).fetch(force: true);
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(title: 'Server deleted');
      context.go(Routes.appHome);
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _deleting = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const VAppBar(title: 'Server settings', leading: VAppBarLeading.back),
      body: _loading && _server == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: VButton(
                    label: 'Save changes',
                    loading: _saving,
                    loadingLabel: 'Saving...',
                    fullWidth: true,
                    size: VButtonSize.lg,
                    onPressed: _saving ? null : _save,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: VButton(
                    label: 'Delete server',
                    variant: VButtonVariant.destructive,
                    loading: _deleting,
                    loadingLabel: 'Deleting...',
                    fullWidth: true,
                    onPressed: _deleting ? null : _confirmDelete,
                    leading: const Icon(LucideIcons.trash2, size: 18),
                  ),
                ),
                const SizedBox(height: 24),
              ],
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
