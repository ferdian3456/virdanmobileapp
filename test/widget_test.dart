import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:virdanmobileapp/app.dart';

void main() {
  testWidgets('App boots and renders login page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VirdanApp()));
    // initial frame may show splash while auth boot probe runs; let it settle.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Welcome To Virdan'), findsOneWidget);
  });
}
