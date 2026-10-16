import '../entities/daily_analytics_summary.dart';
import '../repositories/analytics_repository.dart';

/// Caso de uso para obtener el resumen de analítica del día actual (US-3.2).
class GetTodayAnalyticsUseCase {
  final AnalyticsRepository _repository;

  const GetTodayAnalyticsUseCase(this._repository);

  Future<DailyAnalyticsSummary> call() {
    return _repository.getTodayAnalytics();
  }
}
