import 'package:flutter_test/flutter_test.dart';

import 'package:club_erp_system/main.dart';

void main() {
  testWidgets('App smoke test - loads Login Screen with PIN entry', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ClubErpApp());
    await tester.pumpAndSettle();

    // Verify that the login screen is displayed
    expect(find.text('Ingresa tu PIN'), findsOneWidget);
  });
}

