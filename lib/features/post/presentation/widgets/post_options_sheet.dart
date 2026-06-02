import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/show_api_error_toast.dart';
import '../../../../core/feedback/toast/toast_controller.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/v_button.dart';
import '../../../server/data/server_repository.dart';
import '../../data/post_api.dart';
import '../../domain/post.dart';

/// Owner-only post actions: Edit and Delete. Shown from the overflow button on
/// [PostCard]. [onEdited] fires with the refreshed post after a successful edit;
/// [onDeleted] fires after a successful delete so the caller can drop it from a
/// feed or pop a detail route.
Future<void> showPostOptions({
  required BuildContext context,
  required WidgetRef ref,
  required Post post,
  required ValueChanged<Post> onEdited,
  required VoidCallback onDeleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Post options',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _OptionRow(
            icon: LucideIcons.pencil,
            label: 'Edit post',
            color: const Color(0xFF0F172A),
            onTap: () {
              Navigator.pop(sheetCtx);
              _openEdit(context, post, onEdited);
            },
          ),
          _OptionRow(
            icon: LucideIcons.trash2,
            label: 'Delete post',
            color: AppColors.error,
            onTap: () {
              Navigator.pop(sheetCtx);
              _confirmDelete(context, ref, post, onDeleted);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> _openEdit(
  BuildContext context,
  Post post,
  ValueChanged<Post> onEdited,
) async {
  // Pass the post via `extra` so the edit page prefills without a refetch.
  final updated = await context.push<Post>(Routes.postEdit(post.id), extra: post);
  if (updated != null) onEdited(updated);
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Post post,
  VoidCallback onDeleted,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (_) => _DeleteConfirmSheet(
      post: post,
      serverName: _resolveServerName(ref, post.serverId),
      onDeleted: onDeleted,
    ),
  );
}

String _resolveServerName(WidgetRef ref, String serverId) {
  final servers = ref.read(myServersProvider);
  for (final s in servers.servers) {
    if (s.id == serverId) return s.name;
  }
  return servers.activeServer?.name ?? 'this server';
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Destructive confirmation with the post thumbnail, server context, and the
/// irreversible warning. Owns the in-flight state so the action button can show
/// a spinner while the delete request runs.
class _DeleteConfirmSheet extends ConsumerStatefulWidget {
  const _DeleteConfirmSheet({
    required this.post,
    required this.serverName,
    required this.onDeleted,
  });

  final Post post;
  final String serverName;
  final VoidCallback onDeleted;

  @override
  ConsumerState<_DeleteConfirmSheet> createState() => _DeleteConfirmSheetState();
}

class _DeleteConfirmSheetState extends ConsumerState<_DeleteConfirmSheet> {
  bool _busy = false;

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(postApiProvider).delete(
            serverId: widget.post.serverId,
            postId: widget.post.id,
          );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDeleted();
      ref.read(toastControllerProvider.notifier).success(title: 'Post deleted.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showApiErrorToast(ref, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.post.imageUrl;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: img != null && img.isNotEmpty
                        ? Image.network(
                            img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _thumbFallback(),
                          )
                        : _thumbFallback(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delete this post?',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Removed from ${widget.serverName} permanently.',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            VButton(
              label: 'Delete post',
              loadingLabel: 'Deleting…',
              variant: VButtonVariant.destructive,
              size: VButtonSize.lg,
              fullWidth: true,
              loading: _busy,
              onPressed: _delete,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text(
                'Keep it',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbFallback() {
    return const ColoredBox(
      color: Color(0xFFF1F3F5),
      child: Icon(LucideIcons.imageOff, size: 18, color: AppColors.textTertiary),
    );
  }
}
