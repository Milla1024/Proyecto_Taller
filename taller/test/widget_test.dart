import 'package:flutter_test/flutter_test.dart';

import 'package:taller/main.dart';

void main() {
  testWidgets('Login loads and can open dashboard', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TallerApp());

    expect(find.text('Taller PitStop'), findsOneWidget);
    expect(find.text('Acceso de empleados'), findsOneWidget);
    expect(find.text('Nombre del empleado'), findsOneWidget);
    expect(find.text('Contrasena'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), 'Carlos');
    await tester.enterText(find.byType(EditableText).at(1), '1234');
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Panel principal'), findsOneWidget);
    expect(find.text('Ordenes activas'), findsWidgets);
    expect(find.text('Trabajos realizados'), findsOneWidget);
    expect(find.text('Entregas y avisos'), findsOneWidget);

    expect(find.text('Modulos del sistema'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar sesion'));
    await tester.pumpAndSettle();

    expect(find.text('Taller PitStop'), findsOneWidget);
    expect(find.text('Nombre del empleado'), findsOneWidget);
  });
}
