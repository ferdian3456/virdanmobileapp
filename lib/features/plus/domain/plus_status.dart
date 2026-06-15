import 'package:flutter/foundation.dart';

/// Virdan Plus status + price breakdown for a single server.
/// Maps `GET /servers/:serverId/plus`.
@immutable
class PlusStatus {
  const PlusStatus({
    required this.active,
    required this.durationDays,
    required this.baseIdr,
    required this.taxIdr,
    required this.totalIdr,
    this.expiresAt,
  });

  factory PlusStatus.fromJson(Map<String, dynamic> json) {
    final price = json['price'] as Map<String, dynamic>? ?? const {};
    final expires = json['expiresAt'] as String?;
    return PlusStatus(
      active: (json['active'] as bool?) ?? false,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 30,
      baseIdr: (price['baseIdr'] as num?)?.toInt() ?? 0,
      taxIdr: (price['taxIdr'] as num?)?.toInt() ?? 0,
      totalIdr: (price['totalIdr'] as num?)?.toInt() ?? 0,
      expiresAt: expires != null ? DateTime.tryParse(expires) : null,
    );
  }

  final bool active;
  final int durationDays;
  final int baseIdr;
  final int taxIdr;
  final int totalIdr;
  final DateTime? expiresAt;
}
