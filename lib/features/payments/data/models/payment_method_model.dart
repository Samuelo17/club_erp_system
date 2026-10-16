import 'package:club_erp_system/features/payments/domain/entities/payment_method.dart';

/// Modelo de datos que extiende [PaymentMethod].
/// Encapsula la lógica de serialización / deserialización desde SQLite.
class PaymentMethodModel extends PaymentMethod {
  const PaymentMethodModel({
    required super.id,
    required super.name,
    super.isActive,
  });

  /// Deserializa una fila de SQLite a [PaymentMethodModel].
  factory PaymentMethodModel.fromMap(Map<String, dynamic> map) {
    return PaymentMethodModel(
      id: map['id'] as String,
      name: map['name'] as String,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }

  /// Serializa el modelo a un Map compatible con `db.insert('payment_methods', ...)`.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
    };
  }

  /// Crea un [PaymentMethodModel] a partir de la entidad de dominio.
  factory PaymentMethodModel.fromEntity(PaymentMethod entity) {
    return PaymentMethodModel(
      id: entity.id,
      name: entity.name,
      isActive: entity.isActive,
    );
  }
}
