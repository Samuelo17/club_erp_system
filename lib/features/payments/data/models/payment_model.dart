import 'package:club_erp_system/features/payments/domain/entities/payment.dart';

/// Modelo de datos que extiende [Payment].
/// Encapsula la serialización / deserialización desde SQLite.
///
/// **Nota sobre `bank_name`**: el DDL no tiene columna `bank_name`
/// en la tabla `payments`. Para el MVP, el banco se concatena en
/// `reference_number` con un separador (`|`) para no requerir migración.
/// Formato: `"BANCO|REFERENCIA"`.
///
/// Cuando se haga la migración v3, se separa en columna propia.
class PaymentModel extends Payment {
  const PaymentModel({
    required super.id,
    required super.orderId,
    required super.paymentMethodId,
    required super.amount,
    required super.currency,
    required super.exchangeRate,
    super.referenceNumber,
    super.bankName,
    required super.status,
    required super.createdAt,
  });

  /// Serializa el modelo a un Map compatible con `db.insert('payments', ...)`.
  ///
  /// Combina [bankName] y [referenceNumber] en el campo `reference_number`
  /// usando el separador `|`.
  Map<String, dynamic> toMap() {
    final now = DateTime.now().toIso8601String();
    // Combinar banco y referencia en un solo campo si ambos existen
    String? combinedRef;
    if (bankName != null && bankName!.isNotEmpty) {
      combinedRef = '${bankName!}|${referenceNumber ?? ''}';
    } else {
      combinedRef = referenceNumber;
    }

    return {
      'id': id,
      'order_id': orderId,
      'payment_method_id': paymentMethodId,
      'amount': amount,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'reference_number': combinedRef,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': now,
    };
  }

  /// Deserializa una fila de SQLite a [PaymentModel].
  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    // Separar banco y referencia si existe el separador
    String? bank;
    String? ref;
    final rawRef = map['reference_number'] as String?;
    if (rawRef != null && rawRef.contains('|')) {
      final parts = rawRef.split('|');
      bank = parts[0];
      ref = parts.sublist(1).join('|');
    } else {
      ref = rawRef;
    }

    return PaymentModel(
      id: map['id'] as String,
      orderId: map['order_id'] as String,
      paymentMethodId: map['payment_method_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: map['currency'] as String,
      exchangeRate: (map['exchange_rate'] as num).toDouble(),
      referenceNumber: ref,
      bankName: bank,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Crea un [PaymentModel] a partir de la entidad de dominio.
  factory PaymentModel.fromEntity(Payment entity) {
    return PaymentModel(
      id: entity.id,
      orderId: entity.orderId,
      paymentMethodId: entity.paymentMethodId,
      amount: entity.amount,
      currency: entity.currency,
      exchangeRate: entity.exchangeRate,
      referenceNumber: entity.referenceNumber,
      bankName: entity.bankName,
      status: entity.status,
      createdAt: entity.createdAt,
    );
  }
}
