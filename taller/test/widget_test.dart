import 'package:flutter_test/flutter_test.dart';

import 'package:taller/main.dart';

void main() {
  testWidgets('Main dashboard loads core sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TallerApp());

    expect(find.text('Panel principal'), findsOneWidget);
    expect(find.text('Ordenes activas'), findsWidgets);
    expect(find.text('Trabajos realizados'), findsOneWidget);
    expect(find.text('Entregas y avisos'), findsOneWidget);

    expect(find.text('Modulos del sistema'), findsOneWidget);
  });
}
