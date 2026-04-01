import 'package:flutter_test/flutter_test.dart';
import 'package:sanskar_app/main.dart';

void main() {
  testWidgets('App starts', (WidgetTester tester) async {
    await tester.pumpWidget(const SanskarUtsavApp());
    expect(find.text('संस्कार उत्सव'), findsOneWidget);
  });
}
