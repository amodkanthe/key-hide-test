import 'package:flutter_test/flutter_test.dart';
import 'package:obfs_demo/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KeySecurityDemoApp());
    expect(find.text('1 Key Constant Per Technique'), findsOneWidget);
  });
}
