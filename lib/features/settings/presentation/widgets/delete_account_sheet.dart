import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/errors/show_api_error_toast.dart';
import '../../../../core/feedback/toast/toast_controller.dart';
import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/v_button.dart';
import '../../../auth/data/auth_repository.dart';

/// Destructive account-deletion confirmation, opened from the "Delete Account"
/// row in Settings. Calls `DELETE /users/me` directly (no re-auth, no typed
/// confirmation); on success the auth state flips to anonymous and the router
/// redirects to login.
///
/// [handle] is the user's display handle for the subtitle (e.g. `@nickname`),
/// or null to fall back to a generic phrasing.
Future<void> showDeleteAccountSheet({
  required BuildContext context,
  required WidgetRef ref,
  String? handle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Size to content instead of the default 9/16-height cap, which clipped the
    // last few pixels of the action button on shorter screens (RenderFlex overflow).
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (_) => _DeleteAccountSheet(handle: handle),
  );
}

/// Owns the in-flight state so the action button shows a spinner while the
/// delete request runs.
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet({this.handle});

  final String? handle;

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  bool _busy = false;

  Future<void> _delete() async {
    if (_busy) return;
    setState(() => _busy = true);
    final toast = ref.read(toastControllerProvider.notifier);
    try {
      await ref.read(authRepositoryProvider.notifier).deleteAccount();
      if (!mounted) return;
      // Close the sheet; the auth-state change redirects the user to login.
      Navigator.pop(context);
      toast.success(title: 'Account deleted.');
    } catch (e) {
      // Deletion failed — keep the session and surface the error.
      if (!mounted) return;
      setState(() => _busy = false);
      showApiErrorToast(ref, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handle = widget.handle;
    final subtitle = handle != null && handle.isNotEmpty
        ? 'This permanently removes $handle from Virdan.'
        : 'This permanently removes your account from Virdan.';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(
                LucideIcons.userRoundMinus,
                size: 26,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Delete your account?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.18,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Column(
                children: [
                  _ConsequenceRow(
                    icon: LucideIcons.trash2,
                    text: 'Your posts and comments are permanently deleted',
                  ),
                  _ConsequenceDivider(),
                  _ConsequenceRow(
                    icon: LucideIcons.doorOpen,
                    text: "You're removed from every server you joined",
                  ),
                  _ConsequenceDivider(),
                  _ConsequenceRow(
                    icon: LucideIcons.triangleAlert,
                    text: "This can't be undone",
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            VButton(
              label: 'Delete my account',
              loadingLabel: 'Deleting…',
              variant: VButtonVariant.destructive,
              size: VButtonSize.lg,
              fullWidth: true,
              loading: _busy,
              onPressed: _delete,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text(
                'Keep my account',
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
}

class _ConsequenceRow extends StatelessWidget {
  const _ConsequenceRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsequenceDivider extends StatelessWidget {
  const _ConsequenceDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.divider,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
    );
  }
}
