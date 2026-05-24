import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/feedback/toast/toast_host.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class VirdanApp extends ConsumerWidget {
  const VirdanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'Virdan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => ToastHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
