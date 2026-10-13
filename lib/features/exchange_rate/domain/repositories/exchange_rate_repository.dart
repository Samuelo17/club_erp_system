import '../entities/exchange_rate.dart';

/// Contrato abstracto del repositorio de tasas de cambio.
///
/// Define las operaciones que la capa de dominio necesita sin imponer
/// detalles de implementación (SQLite, PowerSync, etc.).
///
/// Métodos:
/// - [saveExchangeRate]: Inserta un nuevo registro (NUNCA update).
/// - [getLatestExchangeRate]: Lectura puntual de la tasa más reciente.
/// - [watchLatestExchangeRate]: Stream reactivo que emite cada vez que
///   la tabla `exchange_rates` muta (INSERT local o sincronización remota).
abstract class ExchangeRateRepository {
  /// Persiste una nueva tasa de cambio.
  ///
  /// Siempre ejecuta INSERT (historial inmutable).
  /// Lanza excepción si la escritura en SQLite falla.
  Future<void> saveExchangeRate(ExchangeRate rate);

  /// Obtiene la tasa de cambio más reciente (snapshot puntual).
  ///
  /// Retorna `null` si no hay ningún registro en la base de datos.
  Future<ExchangeRate?> getLatestExchangeRate();

  /// Flujo reactivo de la tasa de cambio activa.
  ///
  /// Emite un nuevo valor cada vez que se inserta una tasa nueva,
  /// ya sea localmente o por sincronización de PowerSync.
  Stream<ExchangeRate?> watchLatestExchangeRate();
}
