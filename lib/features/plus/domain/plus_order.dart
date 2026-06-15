import 'package:flutter/foundation.dart';

/// One row in the global payment history. Maps an item of
/// `GET /me/plus-orders`.
@immutable
class PlusOrder {
  const PlusOrder({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.totalIdr,
    required this.status,
    required this.createdAt,
    this.paidAt,
    this.plusExpiresAt,
  });

  factory PlusOrder.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? v) => v != null ? DateTime.tryParse(v) : null;
    return PlusOrder(
      id: json['id'] as String? ?? '',
      serverId: json['serverId'] as String? ?? '',
      serverName: json['serverName'] as String? ?? '',
      totalIdr: (json['totalIdr'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
      createdAt: parse(json['createdAt'] as String?) ?? DateTime.now(),
      paidAt: parse(json['paidAt'] as String?),
      plusExpiresAt: parse(json['plusExpiresAt'] as String?),
    );
  }

  final String id;
  final String serverId;
  final String serverName;
  final int totalIdr;
  final String status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime? plusExpiresAt;
}

/// A page of payment history (cursor pagination).
@immutable
class PlusOrderPage {
  const PlusOrderPage({required this.data, this.nextCursor});

  factory PlusOrderPage.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>? ?? const [])
        .map((e) => PlusOrder.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final page = json['page'] as Map<String, dynamic>?;
    final cursor = page?['nextCursor'] as String?;
    return PlusOrderPage(
      data: list,
      nextCursor: (cursor != null && cursor.isNotEmpty) ? cursor : null,
    );
  }

  final List<PlusOrder> data;
  final String? nextCursor;
}
