import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taller/main.dart';
import 'package:taller/screens/home_screen.dart';

void main() {
  testWidgets('Login loads core fields', (WidgetTester tester) async {
    await tester.pumpWidget(const TallerApp());

    expect(find.text('Taller PitStop'), findsOneWidget);
    expect(find.text('Acceso de empleados'), findsOneWidget);
    expect(find.text('Nombre del empleado'), findsOneWidget);
    expect(find.text('Contrasena'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('Dashboard loads core sections', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: MainShell()));

    expect(find.text('Panel principal'), findsOneWidget);
    expect(find.text('Ordenes activas'), findsWidgets);
    expect(find.text('Trabajos realizados'), findsOneWidget);
    expect(find.text('Entregas y avisos'), findsOneWidget);
    expect(find.text('Modulos del sistema'), findsOneWidget);
  });
}
