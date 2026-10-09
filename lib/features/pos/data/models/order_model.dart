import 'package:club_erp_system/features/pos/domain/entities/order.dart';

/// Modelo de datos que extiende la entidad [Order].
/// Encapsula la lógica de mapeo hacia SQLite.
///
/// Siguiendo el patrón establecido por [ProductModel], este modelo
/// hereda todos los campos de la entidad y agrega la serialización.
class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.employeeId,
    required super.cashSessionId,
    required super.totalAmount,
    super.status,
    required super.createdAt,
  });

  /// Convierte la entidad en un [Map] compatible con `db.insert('orders', ...)`.
  /// SQLite no tiene tipo TIMESTAMPTZ, se almacena como TEXT ISO-8601.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'cash_session_id': cashSessionId,
      'total_amount': totalAmount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': createdAt.toIso8601String(),
    };
  }

  /// Crea un [OrderModel] directamente desde una entidad [Order] de dominio.
  factory OrderModel.fromEntity(Order order) {
    return OrderModel(
      id: order.id,
      employeeId: order.employeeId,
      cashSessionId: order.cashSessionId,
      totalAmount: order.totalAmount,
      status: order.status,
      createdAt: order.createdAt,
    );
  }
}
