import '../entities/exchange_rate.dart';
import '../repositories/exchange_rate_repository.dart';

/// Caso de uso: Observar reactivamente la tasa de cambio activa.
///
/// Expone un [Stream] que emite un nuevo [ExchangeRate] cada vez que
/// la tabla `exchange_rates` sufre una mutación (INSERT local o
/// sincronización remota de PowerSync).
///
/// Este es el mecanismo central de reactividad Offline-First que
/// permite al POS actualizarse instantáneamente cuando la Encargada
/// registra una nueva tasa.
class WatchLatestExchangeRateUseCase {
  final ExchangeRateRepository _repository;

  WatchLatestExchangeRateUseCase(this._repository);

  Stream<ExchangeRate?> call() {
    return _repository.watchLatestExchangeRate();
  }
}
