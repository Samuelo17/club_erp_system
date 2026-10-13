/// Entidad de dominio que representa un registro de tasa de cambio USD → VES.
///
/// Cada registro es un snapshot inmutable de la tasa vigente en el momento en
/// que la Encargada la registró. No se hace UPDATE sobre registros existentes;
/// cada nueva tasa es un INSERT fresco para preservar el historial de auditoría.
///
/// Campos:
/// - [id]: UUIDv4 generado en el cliente (regla de Offline-First).
/// - [rateValue]: Valor numérico positivo de la tasa (ej. 81.4500 VES por 1 USD).
/// - [createdBy]: UUID del empleado/encargada que registró esta tasa.
/// - [createdAt]: Marca de tiempo UTC del momento del registro.
/// - [updatedAt]: Marca de tiempo de auditoría (opcional).
class ExchangeRate {
  final String id;
  final double rateValue;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ExchangeRate({
    required this.id,
    required this.rateValue,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });
}
