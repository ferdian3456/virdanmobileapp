import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:virdanmobileapp/app.dart';

void main() {
  testWidgets('App boots and renders smoke screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VirdanApp()));
    await tester.pumpAndSettle();

    expect(find.text('Smoke Test (dev)'), findsOneWidget);
  });
}
