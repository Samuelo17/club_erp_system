/// Entidad de dominio que representa una orden de venta.
///
/// Mapea directamente la tabla `orders` del DDL.
/// Cumple la regla de **solo UUIDs v4** como llaves primarias.
///
/// **Estado inicial**: toda orden nace con status `PENDING`
/// hasta que se procesen todos los pagos asociados.
class Order {
  final String id;
  final String employeeId;
  final String cashSessionId;
  final double totalAmount;
  final String status;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.employeeId,
    required this.cashSessionId,
    required this.totalAmount,
    this.status = 'PENDING',
    required this.createdAt,
  });

  /// ID corto para visualización rápida en la interfaz de caja (ej. '...a4f9b2').
  String get shortId {
    if (id.length <= 8) return id;
    final lastChars = id.substring(id.length - 6);
    return '...$lastChars';
  }
}
