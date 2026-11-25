import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/main.dart';

void main() {
  testWidgets('Student Credential App smoke test without prefilled credentials', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentCredentialApp());
    expect(find.text('UNIVERSIDAD'), findsOneWidget);
    expect(find.text('INGRESAR A MI CREDENCIAL'), findsOneWidget);

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, hasLength(2));
    expect(fields[0].controller?.text, isEmpty);
    expect(fields[1].controller?.text, isEmpty);
  });
}
