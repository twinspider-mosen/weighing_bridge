import 'package:flutter_test/flutter_test.dart';
import 'package:spider_weighbridge/main.dart';

void main() {
  testWidgets('Weighing Screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WeighingBridgeApp(hasSession: false));

    // Verify that the title is present.
    expect(find.text('WEIGHING BRIDGE OPERATOR DASHBOARD'), findsOneWidget);

    // Verify initial weight display is 0.00
    expect(find.text('0.00'), findsOneWidget);
  });
}
