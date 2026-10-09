import 'package:flutter_test/flutter_test.dart';
import 'package:sipalab/main.dart';
import 'package:sipalab/screens/login_screen.dart';

void main() {
  testWidgets('SIPALAB renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const LabRentApp());

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
