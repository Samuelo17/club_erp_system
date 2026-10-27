// test/widget_test.dart
//
// Smoke test básico del sistema Happy House ERP/POS.
// Verifica que la app arranca y muestra la pantalla de autenticación por PIN.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:club_erp_system/main.dart';

void main() {
  testWidgets('AuthScreen smoke test — muestra teclado numérico',
      (WidgetTester tester) async {
    // Envuelve la app en ProviderScope para que Riverpod funcione en tests
    await tester.pumpWidget(
      const ProviderScope(
        child: HappyHouseApp(),
      ),
    );

    // Esperar a que los frames asíncronos (inicialización de DB) terminen
    await tester.pumpAndSettle();

    // Verificar que la AuthScreen está presente mostrando el texto del PIN
    expect(find.text('Happy House'), findsOneWidget);
    expect(find.text('Ingresa tu PIN para acceder'), findsOneWidget);

    // Verificar que los botones del teclado numérico están presentes
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });
}
