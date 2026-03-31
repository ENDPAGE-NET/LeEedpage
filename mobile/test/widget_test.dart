import 'package:endpage_attendance/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app renders root widget', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: EndpageApp()));
    expect(find.byType(EndpageApp), findsOneWidget);
  });
}
