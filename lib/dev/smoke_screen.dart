import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/feedback/toast/toast_controller.dart';
import '../core/feedback/v_empty_state.dart';
import '../core/feedback/v_field_error.dart';
import '../core/feedback/v_progress_ring.dart';
import '../core/feedback/v_skeleton.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../core/widgets/v_app_bar.dart';
import '../core/widgets/v_avatar.dart';
import '../core/widgets/v_button.dart';
import '../core/widgets/v_input.dart';

/// Phase 0 QA screen. Demos every feedback component + button + input.
/// Reachable at /dev/smoke. Remove once Phase 1+ pages exist.
class SmokeScreen extends ConsumerStatefulWidget {
  const SmokeScreen({super.key});

  @override
  ConsumerState<SmokeScreen> createState() => _SmokeScreenState();
}

class _SmokeScreenState extends ConsumerState<SmokeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitting = false;
  double _progress = 0.0;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _fakeSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _submitting = false);
    ref.read(toastControllerProvider.notifier).success(
          title: 'Email tersimpan',
          caption: _emailCtrl.text,
        );
  }

  Future<void> _fakeUpload() async {
    setState(() => _progress = 0);
    for (var i = 1; i <= 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _progress = i / 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final toast = ref.read(toastControllerProvider.notifier);
    return Scaffold(
      appBar: VAppBar(
        title: 'Smoke Test (dev)',
        leading: VAppBarLeading.none,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.bell),
            tooltip: 'Notifications',
            onPressed: () => ref.read(toastControllerProvider.notifier).info(
                  title: 'Action tapped',
                ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _Section('VAvatar', [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    VAvatar(fallbackInitial: 'V', size: VAvatarSize.xs),
                    SizedBox(width: AppSpacing.md),
                    VAvatar(fallbackInitial: 'V', size: VAvatarSize.sm),
                    SizedBox(width: AppSpacing.md),
                    VAvatar(fallbackInitial: 'V'),
                    SizedBox(width: AppSpacing.md),
                    VAvatar(fallbackInitial: 'V', size: VAvatarSize.lg),
                    SizedBox(width: AppSpacing.md),
                    VAvatar(fallbackInitial: 'V', size: VAvatarSize.xl),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const VAvatar(
                      url: 'https://i.pravatar.cc/200?img=15',
                      fallbackInitial: 'F',
                      size: VAvatarSize.lg,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const VAvatar(
                      url: 'https://invalid-host.example/not-found.jpg',
                      fallbackInitial: 'X',
                      size: VAvatarSize.lg,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    const VAvatar(fallbackInitial: 'A', size: VAvatarSize.lg),
                    const SizedBox(width: AppSpacing.md),
                    Text('URL · error fallback · no URL',
                        style: AppTextStyles.caption),
                  ],
                ),
              ]),
              _Section('Toast', [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    VButton(
                      label: 'Success',
                      size: VButtonSize.sm,
                      onPressed: () => toast.success(
                        title: 'Post berhasil dibuat',
                      ),
                    ),
                    VButton(
                      label: 'Error + retry',
                      size: VButtonSize.sm,
                      variant: VButtonVariant.destructive,
                      onPressed: () => toast.error(
                        title: 'Gagal memuat feed',
                        caption: 'Periksa koneksi',
                        onRetry: () => toast.info(title: 'Retry tapped'),
                      ),
                    ),
                    VButton(
                      label: 'Warning',
                      size: VButtonSize.sm,
                      variant: VButtonVariant.outline,
                      onPressed: () => toast.warning(title: 'Koneksi lambat'),
                    ),
                    VButton(
                      label: 'Info',
                      size: VButtonSize.sm,
                      variant: VButtonVariant.ghost,
                      onPressed: () => toast.info(title: 'Tip: tarik untuk refresh'),
                    ),
                  ],
                ),
              ]),
              _Section('Button — variants × sizes', [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    VButton(label: 'Primary', onPressed: () {}),
                    VButton(label: 'Secondary', variant: VButtonVariant.secondary, onPressed: () {}),
                    VButton(label: 'Ghost', variant: VButtonVariant.ghost, onPressed: () {}),
                    VButton(label: 'Destructive', variant: VButtonVariant.destructive, onPressed: () {}),
                    VButton(label: 'Outline', variant: VButtonVariant.outline, onPressed: () {}),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    VButton(label: 'sm', size: VButtonSize.sm, onPressed: () {}),
                    VButton(label: 'md', onPressed: () {}),
                    VButton(label: 'lg', size: VButtonSize.lg, onPressed: () {}),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                VButton(label: 'Disabled', onPressed: null),
                const SizedBox(height: AppSpacing.sm),
                VButton(label: 'With leading icon', leading: const Icon(LucideIcons.plus), onPressed: () {}),
              ]),
              _Section('Form + Input + button loading', [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      VInput(
                        controller: _emailCtrl,
                        label: 'Email',
                        hint: 'kamu@example.com',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email wajib diisi';
                          if (!v.contains('@')) return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      VInput(
                        label: 'Password',
                        obscure: true,
                        validator: (v) =>
                            (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      VButton(
                        label: 'Simpan',
                        loadingLabel: 'Menyimpan...',
                        loading: _submitting,
                        fullWidth: true,
                        size: VButtonSize.lg,
                        onPressed: _submitting ? null : _fakeSubmit,
                      ),
                    ],
                  ),
                ),
              ]),
              _Section('VFieldError (inline)', [
                const VFieldError(message: 'Username sudah dipakai. Coba yang lain.'),
              ]),
              _Section('Skeleton', [
                const VSkeleton(height: 16, width: 200),
                const SizedBox(height: AppSpacing.sm),
                const VSkeleton(height: 16),
                const SizedBox(height: AppSpacing.sm),
                const VSkeleton(height: 16, width: 140),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const VSkeleton.circle(size: 40),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          VSkeleton(height: 14, width: 120),
                          SizedBox(height: AppSpacing.xs),
                          VSkeleton(height: 12, width: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ]),
              _Section('VProgressRing', [
                Row(
                  children: [
                    VProgressRing(progress: _progress, label: 'Mengunggah'),
                    const SizedBox(width: AppSpacing.lg),
                    VButton(label: 'Start fake upload', size: VButtonSize.sm, onPressed: _fakeUpload),
                  ],
                ),
              ]),
              _Section('VEmptyState', [
                SizedBox(
                  height: 240,
                  child: VEmptyState(
                    icon: LucideIcons.fileText,
                    title: 'Belum ada post',
                    subtitle: 'Jadi yang pertama posting di server ini!',
                    cta: VButton(label: 'Buat post', onPressed: () {}),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.huge),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}
