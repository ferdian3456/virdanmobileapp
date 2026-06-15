import 'package:flutter/material.dart';
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart' as custom_tabs;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/show_api_error_toast.dart';
import '../../../core/feedback/toast/toast_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/v_app_bar.dart';
import '../../../core/widgets/v_button.dart';
import '../data/plus_api.dart';
import '../data/plus_providers.dart';
import '../domain/plus_format.dart';
import '../domain/plus_status.dart';

/// Checkout for a server's Virdan Plus upgrade. Shows the price breakdown
/// (from `GET /plus`), starts a Xendit payment session on "Pay Now", opens the
/// hosted payment page in a custom tab, then polls status when the app resumes.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.serverId});

  final String serverId;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage>
    with WidgetsBindingObserver {
  bool _starting = false;
  bool _polling = false;
  // True after the hosted payment page has been opened; the next app-resume
  // triggers status polling.
  bool _awaitingReturn = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingReturn && !_polling) {
      _pollStatus();
    }
  }

  Future<void> _payNow(PlusStatus status) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final CheckoutResult result =
          await ref.read(plusApiProvider).checkout(widget.serverId);
      if (!mounted) return;
      if (result.paymentUrl.isEmpty) {
        showApiErrorToast(ref, StateError('Empty payment URL'));
        return;
      }
      _awaitingReturn = true;
      await custom_tabs.launchUrl(
        Uri.parse(result.paymentUrl),
        customTabsOptions: custom_tabs.CustomTabsOptions(
          colorSchemes: custom_tabs.CustomTabsColorSchemes.defaults(
            toolbarColor: AppColors.primary,
          ),
          showTitle: true,
        ),
        safariVCOptions: const custom_tabs.SafariViewControllerOptions(
          barCollapsingEnabled: true,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _awaitingReturn = false;
      // Mutation — no retry button (avoid creating duplicate orders).
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Polls the status endpoint until the webhook grants Plus or we time out.
  /// Polling only reads status; the grant itself is done server-side by the
  /// webhook, so a timeout here does not mean the payment failed.
  Future<void> _pollStatus() async {
    if (_polling || _completed) return;
    setState(() => _polling = true);
    const interval = Duration(seconds: 2);
    const maxAttempts = 15; // ~30s
    try {
      for (var i = 0; i < maxAttempts; i++) {
        if (!mounted) return;
        try {
          final status = await ref.read(plusApiProvider).getStatus(widget.serverId);
          if (status.active) {
            _completed = true;
            _awaitingReturn = false;
            if (!mounted) return;
            ref.invalidate(plusStatusProvider(widget.serverId));
            ref.read(toastControllerProvider.notifier).success(
                  title: 'Virdan Plus activated',
                  caption: 'Your server can now upload files up to 100 MB.',
                );
            context.pop(true);
            return;
          }
        } catch (_) {
          // Transient read error — keep polling.
        }
        await Future<void>.delayed(interval);
      }
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).info(
            title: 'Payment is being processed',
            caption: 'It may take a moment. Pull to refresh shortly.',
          );
    } finally {
      if (mounted) setState(() => _polling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(plusStatusProvider(widget.serverId));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const VAppBar(title: 'Checkout'),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 3)),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.invalidate(plusStatusProvider(widget.serverId)),
        ),
        data: (status) {
          if (status.active) {
            // Already plus (e.g. granted in another session) — nothing to buy.
            return _AlreadyActive(onBack: () => context.pop());
          }
          return _Content(
            status: status,
            polling: _polling,
            starting: _starting,
            onPay: () => _payNow(status),
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.status,
    required this.polling,
    required this.starting,
    required this.onPay,
  });

  final PlusStatus status;
  final bool polling;
  final bool starting;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Hero(totalIdr: status.totalIdr),
              const SizedBox(height: 20),
              Text(
                'ORDER DETAILS',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),
              _OrderDetails(status: status),
              const SizedBox(height: 16),
              const _SecureNote(),
              if (polling) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Confirming your payment…',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VButton(
                  label: 'Pay Now  ·  ${formatRupiah(status.totalIdr)}',
                  leading: const Icon(LucideIcons.lock),
                  loading: starting,
                  loadingLabel: 'Starting…',
                  fullWidth: true,
                  size: VButtonSize.lg,
                  onPressed: onPay,
                ),
                const SizedBox(height: 8),
                Text(
                  "By continuing you agree to Virdan's Terms & Conditions",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.totalIdr});

  final int totalIdr;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B5BFF), Color(0xFF4F46E5)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(LucideIcons.sparkles, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                  'Virdan Plus',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            formatRupiah(totalIdr),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One-time purchase · includes tax',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(LucideIcons.upload, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text(
                  '100 MB uploads',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetails extends StatelessWidget {
  const _OrderDetails({required this.status});

  final PlusStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _row('Virdan Plus', formatRupiah(status.baseIdr)),
          const Divider(height: 1, color: AppColors.border),
          _row('Tax', formatRupiah(status.taxIdr)),
          const Divider(height: 1, color: AppColors.border),
          _row('Total', formatRupiah(status.totalIdr), emphasize: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: emphasize ? AppColors.primary : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(LucideIcons.lock, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure & encrypted payment',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Powered by Xendit',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlreadyActive extends StatelessWidget {
  const _AlreadyActive({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.circleCheck, size: 44, color: AppColors.success),
            const SizedBox(height: 12),
            Text(
              'This server already has Virdan Plus',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyStrong,
            ),
            const SizedBox(height: 16),
            VButton(label: 'Back', variant: VButtonVariant.secondary, onPressed: onBack),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.triangleAlert, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              "Couldn't load checkout",
              style: AppTextStyles.bodyStrong,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            VButton(label: 'Retry', variant: VButtonVariant.secondary, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
