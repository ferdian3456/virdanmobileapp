import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

abstract final class AppTextStyles {
  static TextStyle get _base => GoogleFonts.inter(
        color: AppColors.textPrimary,
        height: 1.4,
      );

  static TextStyle get display => _base.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get h1 => _base.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
      );

  static TextStyle get h2 => _base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get h3 => _base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle get body => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => _base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get bodyStrong => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get caption => _base.copyWith(
        fontSize: 14,
        color: AppColors.textSecondary,
      );

  static TextStyle get captionStrong => _base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get micro => _base.copyWith(
        fontSize: 12,
        color: AppColors.textTertiary,
      );

  static TextStyle get button => _base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );
}
