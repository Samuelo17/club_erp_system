import 'package:club_erp_system/features/cash_closure/domain/entities/cash_session.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment.dart';

/// Contrato abstracto para las operaciones de sesión y cierre de caja (US-3.4).
abstract class CashSessionRepository {
  /// Obtiene la sesión de caja actualmente abierta ('OPEN').
  Future<CashSession?> getActiveSession();

  /// Obtiene los totales sumados agrupados por método de pago para una sesión.
  ///
  /// Retorna un mapa con los 4 métodos estándar:
  /// - 'Efectivo USD'
  /// - 'Efectivo VES'
  /// - 'Pago Móvil'
  /// - 'Punto de Venta'
  Future<Map<String, double>> getSessionTotalsByMethod(String sessionId);

  /// Obtiene los pagos individuales asociados a una sesión y a un método de pago.
  ///
  /// Ejecuta un JOIN entre payments y orders para traer el detalle de cada pago.
  Future<List<Payment>> getPaymentsBySessionAndMethod(
    String sessionId,
    String methodId,
  );

  /// Cierra formalmente la sesión de caja actualizando status = 'CLOSED'
  /// y registrando la fecha/hora de término.
  Future<void> closeSession(String sessionId);
}
