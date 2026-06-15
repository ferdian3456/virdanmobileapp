import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/http/dio_client.dart';
import '../domain/plus_order.dart';
import '../domain/plus_status.dart';

/// Result of starting a checkout: the order id plus the Xendit hosted payment
/// page URL to open in a custom tab.
typedef CheckoutResult = ({String orderId, String paymentUrl});

class PlusApi {
  PlusApi(this._dio);

  final Dio _dio;

  Future<PlusStatus> getStatus(String serverId) async {
    final res = await _dio.get<Map<String, dynamic>>('/servers/$serverId/plus');
    return PlusStatus.fromJson(res.data ?? const {});
  }

  Future<CheckoutResult> checkout(String serverId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/servers/$serverId/plus/checkout',
    );
    final data = res.data ?? const {};
    return (
      orderId: (data['orderId'] as String?) ?? '',
      paymentUrl: (data['paymentUrl'] as String?) ?? '',
    );
  }

  Future<PlusOrderPage> listMyOrders({String? cursor}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/me/plus-orders',
      queryParameters: {'limit': 20, 'cursor': ?cursor},
    );
    return PlusOrderPage.fromJson(res.data ?? const {});
  }
}

final plusApiProvider = Provider<PlusApi>((ref) {
  return PlusApi(ref.read(apiDioProvider));
});
