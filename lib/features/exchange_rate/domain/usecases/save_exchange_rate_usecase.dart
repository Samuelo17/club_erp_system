import '../entities/exchange_rate.dart';
import '../repositories/exchange_rate_repository.dart';

/// Caso de uso: Registrar una nueva tasa de cambio.
///
/// Validaciones de negocio:
/// - [rateValue] debe ser un número positivo (> 0).
/// - [createdBy] no puede estar vacío (se requiere trazabilidad).
///
/// Delega la persistencia al repositorio inyectado.
class SaveExchangeRateUseCase {
  final ExchangeRateRepository _repository;

  SaveExchangeRateUseCase(this._repository);

  Future<void> call(ExchangeRate rate) async {
    // Validación de negocio: la tasa debe ser positiva.
    if (rate.rateValue <= 0) {
      throw ArgumentError(
        'La tasa de cambio debe ser un valor positivo. '
        'Valor recibido: ${rate.rateValue}',
      );
    }

    // Validación de trazabilidad: se requiere el ID del empleado.
    if (rate.createdBy.isEmpty) {
      throw ArgumentError(
        'Se requiere el ID del empleado que registra la tasa (createdBy).',
      );
    }

    await _repository.saveExchangeRate(rate);
  }
}
