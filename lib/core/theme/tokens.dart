import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF007BFF);
  static const primarySoft = Color(0xFFE7F1FF);
  static const primaryDark = Color(0xFF0056CC);

  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF8F9FA);
  static const border = Color(0xFFDEE2E6);
  static const divider = Color(0xFFE9ECEF);

  static const textPrimary = Color(0xFF212529);
  static const textSecondary = Color(0xFF6C757D);
  static const textTertiary = Color(0xFFADB5BD);
  static const textOnPrimary = Color(0xFFFFFFFF);

  static const success = Color(0xFF28A745);
  static const error = Color(0xFFDC3545);
  static const warning = Color(0xFFFFC107);
  static const info = Color(0xFF17A2B8);

  static const overlay = Color(0x80000000);
  static const skeletonBase = Color(0xFFE9ECEF);
  static const skeletonHighlight = Color(0xFFF8F9FA);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 14.0;
  static const xl = 16.0;
  static const xxl = 24.0;
  static const pill = 999.0;
}

abstract final class AppElevation {
  static const none = <BoxShadow>[];

  static const card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const sheet = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, -2)),
  ];

  static const overlay = [
    BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 8)),
  ];
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
  static const toast = Duration(milliseconds: 2600);
  static const toastError = Duration(milliseconds: 5000);
  static const toastWarning = Duration(milliseconds: 3500);

  static const standardCurve = Curves.easeInOutCubic;
  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
}
