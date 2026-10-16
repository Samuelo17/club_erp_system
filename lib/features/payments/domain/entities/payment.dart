/// Entidad de dominio que representa un pago registrado.
///
/// Mapea la tabla `payments` del DDL.
///
/// **Inmutabilidad Financiera (Regla #2 del AI_CONTEXT)**:
/// [exchangeRate] es la tasa de cambio **congelada** en el instante exacto
/// del pago. Si la tasa cambia mañana, este registro NO se ve afectado.
///
/// **Estados válidos del campo [status]**:
/// - `PENDING_VALIDATION`: Pago digital (Pago Móvil / Punto de Venta) aún
///   no verificado por la Encargada.
/// - `APROBADO_VISUALMENTE`: La Encargada aprobó visualmente (sin internet).
/// - `CONCILIADO`: Efectivo verificado o pago digital ya conciliado en la nube.
class Payment {
  final String id;
  final String orderId;
  final String paymentMethodId;
  final double amount;
  final String currency; // 'USD' | 'VES'
  final double exchangeRate; // Tasa congelada al momento del pago
  final String? referenceNumber; // Referencia del banco (Pago Móvil / POS)
  final String? bankName; // Banco emisor (Pago Móvil / POS)
  final String
  status; // 'PENDING_VALIDATION' | 'APROBADO_VISUALMENTE' | 'CONCILIADO'
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.paymentMethodId,
    required this.amount,
    required this.currency,
    required this.exchangeRate,
    this.referenceNumber,
    this.bankName,
    required this.status,
    required this.createdAt,
  });

  /// Monto equivalente en USD calculado con la tasa congelada del pago.
  double get amountInUsd => currency == 'USD'
      ? amount
      : (exchangeRate > 0 ? amount / exchangeRate : 0.0);

  /// Monto equivalente en VES calculado con la tasa congelada del pago.
  double get amountInVes => currency == 'VES' ? amount : amount * exchangeRate;

  /// ID corto de la orden para visualización rápida en UI (ej: "8A3F2C10").
  String get orderShortId =>
      orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId.toUpperCase();

  /// Hora formateada de la transacción (ej: "10:45 AM").
  String get formattedTime {
    final hour = createdAt.hour > 12
        ? createdAt.hour - 12
        : (createdAt.hour == 0 ? 12 : createdAt.hour);
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final period = createdAt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
