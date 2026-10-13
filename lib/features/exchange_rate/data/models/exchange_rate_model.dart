import '../../domain/entities/exchange_rate.dart';

/// Modelo de datos para serialización/deserialización de [ExchangeRate]
/// desde y hacia las filas de SQLite (PowerSync).
///
/// Convenciones de mapeo:
/// - `rate_value` (REAL en SQLite) ↔ `double` en Dart.
/// - `created_at`, `updated_at` (TEXT ISO-8601 en SQLite) ↔ `DateTime` en Dart.
/// - `created_by` (TEXT UUID en SQLite) ↔ `String` en Dart.
class ExchangeRateModel {
  final String id;
  final double rateValue;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExchangeRateModel({
    required this.id,
    required this.rateValue,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  /// Deserializa una fila de SQLite (Map) a un [ExchangeRateModel].
  factory ExchangeRateModel.fromMap(Map<String, dynamic> map) {
    return ExchangeRateModel(
      id: map['id'] as String,
      rateValue: (map['rate_value'] as num).toDouble(),
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  /// Serializa el modelo a un Map compatible con INSERT de SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rate_value': rateValue,
      'created_by': createdBy,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  /// Convierte un [ExchangeRateModel] a la entidad de dominio [ExchangeRate].
  ExchangeRate toEntity() {
    return ExchangeRate(
      id: id,
      rateValue: rateValue,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Crea un [ExchangeRateModel] a partir de la entidad de dominio.
  factory ExchangeRateModel.fromEntity(ExchangeRate entity) {
    return ExchangeRateModel(
      id: entity.id,
      rateValue: entity.rateValue,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
