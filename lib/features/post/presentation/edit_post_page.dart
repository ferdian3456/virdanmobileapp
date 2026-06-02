import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../data/post_api.dart';
import '../domain/post.dart';

/// Caption-only post editor. Mirrors the create composer's "Detail" step but
/// the image is fixed (backend PUT accepts caption only) and all fields are
/// prefilled. Saving returns the refreshed [Post] to the caller via pop.
///
/// Backend caps the caption at 2000 chars (create + update alike). The create
/// composer currently shows /2200 — a pre-existing FE/BE mismatch; this page
/// uses the correct 2000 to avoid a 400 on save.
const int _captionMax = 2000;

class EditPostPage extends ConsumerStatefulWidget {
  const EditPostPage({super.key, required this.postId, this.initialPost});

  final String postId;
  final Post? initialPost;

  @override
  ConsumerState<EditPostPage> createState() => _EditPostPageState();
}

class _EditPostPageState extends ConsumerState<EditPostPage> {
  final _captionCtrl = TextEditingController();
  Post? _post;
  String _originalCaption = '';
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _captionCtrl.addListener(() => setState(() {}));
    final initial = widget.initialPost;
    if (initial != null) {
      _applyPost(initial);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  void _applyPost(Post post) {
    _post = post;
    _originalCaption = post.caption;
    _captionCtrl.text = post.caption;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final post = await ref.read(postApiProvider).getById(widget.postId);
      if (!mounted) return;
      setState(() => _applyPost(post));
    } catch (e) {
      if (!mounted) return;
      showApiErrorToast(ref, e, onRetry: _load);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canSave {
    final caption = _captionCtrl.text.trim();
    return _post != null &&
        !_saving &&
        caption.isNotEmpty &&
        caption != _originalCaption.trim();
  }

  Future<void> _save() async {
    final post = _post;
    if (post == null || !_canSave) return;
    setState(() => _saving = true);
    try {
      final updated = await ref.read(postApiProvider).updateCaption(
            serverId: post.serverId,
            postId: post.id,
            caption: _captionCtrl.text.trim(),
          );
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).success(title: 'Post updated.');
      context.pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showApiErrorToast(ref, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const VAppBar(title: 'Edit post', leading: VAppBarLeading.back),
      body: _post == null
          ? Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text(
                      'Post not found',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: AppColors.textSecondary,
                      ),
                    ),
            )
          : Column(
              children: [
                Expanded(child: _buildBody()),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildBody() {
    final post = _post!;
    final img = post.imageUrl;
    final captionLen = _captionCtrl.text.characters.length;
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      children: [
        if (img != null && img.isNotEmpty) ...[
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 200,
                height: 200,
                child: Image.network(
                  img,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFF1F3F5),
                    child: Center(
                      child: Icon(LucideIcons.imageOff,
                          color: AppColors.textTertiary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              TextField(
                controller: _captionCtrl,
                maxLines: 4,
                minLines: 4,
                maxLength: _captionMax,
                enabled: !_saving,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Write a caption…',
                  hintStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: AppColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  counterText: '',
                  contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
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
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 12, 8),
                child: Text(
                  '$captionLen/$_captionMax',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: captionLen > _captionMax - 100
                        ? AppColors.error
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Decorative rows kept for parity with the create composer; not yet
        // wired (mirrors create — both pending real implementation).
        const _MetaRow(icon: LucideIcons.users, label: 'Tag people'),
        const _MetaRow(icon: LucideIcons.mapPin, label: 'Add location'),
        const _MetaRow(icon: LucideIcons.music, label: 'Add music'),
        const SizedBox(height: 8),
        const _ToggleRow(
          title: 'Post to other servers',
          help: 'Share to multiple servers at once',
        ),
        const _ToggleRow(
          title: 'Hide like count',
          help: 'Only you can see how many likes this post gets',
        ),
        const _ToggleRow(
          title: 'Turn off commenting',
          help: "Members can't comment on this post",
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F3F5))),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SafeArea(
        top: false,
        child: Opacity(
          opacity: _canSave ? 1 : 0.4,
          child: Material(
            color: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _canSave ? _save : null,
              child: SizedBox(
                height: 48,
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
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
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Opacity(
        opacity: 0.7,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF495057)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronRight,
                  size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.title, required this.help});

  final String title;
  final String help;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Opacity(
        opacity: 0.7,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
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
            ),
            Switch.adaptive(
              value: false,
              onChanged: null,
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
