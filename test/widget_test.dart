import 'package:flutter_test/flutter_test.dart';
import 'package:hisaab_brabar/app.dart';

void main() {
  testWidgets('Hisaab Brabar launches', (WidgetTester tester) async {
    await tester.pumpWidget(const HisaabBrabarApp());

    // Check if the app title is displayed.
    expect(find.text('Hisaab Brabar'), findsOneWidget);

    // Check if the home screen is displayed.
    expect(find.text('TOTAL NET BALANCE'), findsOneWidget);
  });
}
