import 'package:flutter_test/flutter_test.dart';
import 'package:inkframe/features/lock/lock_screen.dart';

import '../../_harness/test_app.dart';

void main() {
  testWidgets('LockScreen renders logo + unlock CTA', (tester) async {
    await pumpInkApp(tester, const LockScreen());
    await tester.pumpAndSettle();
    expect(find.text('Ink'), findsOneWidget);
    expect(find.text('Frame'), findsOneWidget);
    expect(find.text('Unlock'), findsOneWidget);
    expect(find.text('A DESK FOR STORYBOARDERS'), findsOneWidget);
  });
}
