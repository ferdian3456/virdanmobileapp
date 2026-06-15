import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/plus_status.dart';
import 'plus_api.dart';

/// Virdan Plus status for a server, keyed by serverId. Used by the checkout
/// page (price breakdown) and as the source for refresh-on-resume polling.
final plusStatusProvider = FutureProvider.family<PlusStatus, String>((ref, serverId) {
  return ref.read(plusApiProvider).getStatus(serverId);
});
