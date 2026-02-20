import 'package:flutter_test/flutter_test.dart';
import 'package:minuto_a_minuto/main.dart';

void main() {
  testWidgets('App inicia correctamente', (WidgetTester tester) async {
    await tester.pumpWidget(const MinutoAMinutoApp());
    expect(find.text('MINUTO A MINUTO'), findsOneWidget);
  });
}
