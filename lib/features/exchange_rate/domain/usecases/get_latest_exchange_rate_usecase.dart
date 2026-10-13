import '../entities/exchange_rate.dart';
import '../repositories/exchange_rate_repository.dart';

/// Caso de uso: Obtener la tasa de cambio más reciente (lectura puntual).
///
/// Consulta única que retorna la tasa activa o `null` si no hay registros.
class GetLatestExchangeRateUseCase {
  final ExchangeRateRepository _repository;

  GetLatestExchangeRateUseCase(this._repository);

  Future<ExchangeRate?> call() async {
    return _repository.getLatestExchangeRate();
  }
}
