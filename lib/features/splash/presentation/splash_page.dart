import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/util/app_assets.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/auth_state.dart';

/// Branded splash shown on cold start. Holds for a short minimum so the lockup
/// is visible, then routes to home (authenticated) or login. The router's
/// redirect refines home -> onboarding when the user has no servers.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _minElapsed = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _minElapsed = true);
    });
  }

  void _maybeNavigate(AuthState? auth) {
    if (_navigated || !_minElapsed || auth == null) return;
    _navigated = true;
    final target = auth is AuthAuthenticated ? Routes.appHome : Routes.authLogin;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    _maybeNavigate(ref.watch(authRepositoryProvider).asData?.value);

    return Scaffold(
      backgroundColor: Colors.white,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.0,
            colors: [Color(0x14007BFF), Color(0x00007BFF)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(AppAssets.logoMark, height: 76),
                      const SizedBox(width: 20),
                      Text.rich(
                        TextSpan(
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 76,
                            letterSpacing: -3.4,
                            height: 1.0,
                            color: const Color(0xFF14142B),
                          ),
                          children: const [
                            TextSpan(text: 'virdan'),
                            TextSpan(
                              text: '.',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'One you, many communities.',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  letterSpacing: 0.3,
                  color: const Color(0xFF6B6D80),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
