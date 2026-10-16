import 'package:club_erp_system/features/payments/domain/entities/payment.dart';
import 'package:club_erp_system/features/payments/domain/entities/payment_method.dart';

/// Contrato abstracto para el repositorio de pagos.
///
/// La capa de Domain define QUÉ necesita, sin conocer el CÓMO.
/// La implementación concreta reside en la capa Data.
abstract class PaymentRepository {
  /// Retorna todos los métodos de pago activos disponibles en la base de datos.
  ///
  /// Se usa para poblar el selector de métodos de pago en el checkout.
  /// Si la tabla está vacía, se carga el seeding por defecto.
  Future<List<PaymentMethod>> getPaymentMethods();

  /// Persiste un pago en SQLite de forma atómica.
  ///
  /// [payment] ya debe tener su UUID v4 generado en el cliente,
  /// la tasa de cambio congelada y el estado inicial correspondiente
  /// al método de pago seleccionado.
  Future<void> processPayment(Payment payment);

  /// Obtiene todos los pagos con estado 'PENDING_VALIDATION' (pagos digitales no conciliados).
  ///
  /// Utilizado por el panel de gerencia / encargada (US-3.1) para validar
  /// pagos móviles y puntos de venta.
  Future<List<Payment>> getPendingPayments();

  /// Actualiza el estado de un pago a 'CONCILIADO' en SQLite.
  ///
  /// Llamado cuando la Encargada valida el pago con su portal bancario.
  Future<void> approvePayment(String paymentId);
}
