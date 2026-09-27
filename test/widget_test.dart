// This is a basic Flutter widget test.

import 'package:flutter_test/flutter_test.dart';
import 'package:autoclicker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RapidoAutoClickerApp());
    expect(find.text('Auto Clicker'), findsOneWidget);
  });
}
