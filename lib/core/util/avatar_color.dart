import 'package:flutter/material.dart';

const _avatarPalette = [
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFFF59E0B),
  Color(0xFF10B981),
  Color(0xFF06B6D4),
  Color(0xFF3B82F6),
  Color(0xFFEF4444),
  Color(0xFF7C3AED),
];

/// Deterministic color from a seed (server short name / username initial).
Color avatarColorFor(String seed) {
  if (seed.isEmpty) return _avatarPalette[0];
  var hash = 0;
  for (final code in seed.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _avatarPalette[hash % _avatarPalette.length];
}

String formatCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 10000) return '${(value / 1000).toStringAsFixed(0)}k';
  if (value >= 1000) {
    final s = (value / 1000).toStringAsFixed(1);
    return s.endsWith('.0') ? '${s.substring(0, s.length - 2)}k' : '${s}k';
  }
  return value.toString();
}
