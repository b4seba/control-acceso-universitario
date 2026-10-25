import 'package:flutter_test/flutter_test.dart';
import 'package:student_app/main.dart';

void main() {
  testWidgets('Student Credential App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StudentCredentialApp());
    expect(find.text('UNIVERSIDAD'), findsOneWidget);
    expect(find.text('INGRESAR A MI CREDENCIAL'), findsOneWidget);
  });
}
