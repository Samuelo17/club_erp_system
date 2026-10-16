import '../entities/daily_analytics_summary.dart';

/// Contrato abstracto para el repositorio de estadísticas gerenciales (US-3.2).
abstract class AnalyticsRepository {
  /// Ejecuta agregaciones matemáticas directas en SQLite (SUM, COUNT)
  /// para calcular los KPIs del turno actual filtrando estrictamente por la fecha de hoy.
  Future<DailyAnalyticsSummary> getTodayAnalytics();
}
