import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

// Matches XENDIT_SUCCESS_URL / XENDIT_CANCEL_URL path suffixes (see
// services/payment/xendit.go) — used to detect when the embedded payment
// page has finished, regardless of environment domain.
const _successUrlSuffix = '/payment/success';
const _cancelUrlSuffix = '/payment/cancel';

/// Checkout for a server's Virdan Plus upgrade. Shows the price breakdown
/// (from `GET /plus`), starts a Xendit payment session on "Pay Now", then
/// renders the hosted payment page in an embedded WebView on this same page
/// so it feels native instead of opening a separate browser.
class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key, required this.serverId});

  final String serverId;

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  bool _starting = false;
  bool _polling = false;
  bool _completed = false;
  WebViewController? _webViewController;

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
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(onNavigationRequest: _onNavigationRequest),
        )
        ..loadRequest(Uri.parse(result.paymentUrl));
      setState(() => _webViewController = controller);
    } catch (e) {
      if (!mounted) return;
      // Mutation — no retry button (avoid creating duplicate orders).
      showApiErrorToast(ref, e);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Intercepts navigation inside the embedded payment page: detects the
  /// Xendit success/cancel redirect, and hands off any non-http(s) scheme
  /// (e.g. `gojek://`, `ovo://` e-wallet deep links) to the OS instead of
  /// letting the WebView fail to load it.
  FutureOr<NavigationDecision> _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.navigate;

    if (uri.path.endsWith(_successUrlSuffix)) {
      setState(() => _webViewController = null);
      _pollStatus();
      return NavigationDecision.prevent;
    }
    if (uri.path.endsWith(_cancelUrlSuffix)) {
      setState(() => _webViewController = null);
      return NavigationDecision.prevent;
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      unawaited(
        launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) {
          // No app installed to handle this deep link — nothing to recover;
          // the user stays on the payment page and can pick another method.
          return false;
        }),
      );
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
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
    if (_webViewController != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: VAppBar(
          title: 'Payment',
          onLeadingTap: () => setState(() => _webViewController = null),
        ),
        body: WebViewWidget(controller: _webViewController!),
      );
    }
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
