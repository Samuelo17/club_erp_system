import 'package:flutter/foundation.dart';

import '../../domain/entities/daily_analytics_summary.dart';
import '../../domain/entities/top_product_item.dart';
import '../../domain/repositories/analytics_repository.dart';

/// Provider reactivo para las estadísticas y analítica gerencial del día (US-3.2).
class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsRepository _repository;

  DailyAnalyticsSummary _summary = const DailyAnalyticsSummary.empty();
  bool _isLoading = false;
  String? _errorMessage;

  AnalyticsProvider({required AnalyticsRepository repository})
      // ignore: prefer_initializing_formals
      : _repository = repository {
    loadTodayAnalytics();
  }

  /// Resumen completo de métricas del día.
  DailyAnalyticsSummary get summary => _summary;

  /// Total vendido hoy en USD.
  double get totalUsd => _summary.totalUsd;

  /// Total recaudado hoy en VES.
  double get totalVes => _summary.totalVes;

  /// Cantidad de órdenes procesadas en el día.
  int get ordersCount => _summary.ordersCount;

  /// Top 3 de productos más vendidos.
  List<TopProductItem> get topProducts => _summary.topProducts;

  /// `true` mientras se calculan las métricas en SQLite.
  bool get isLoading => _isLoading;

  /// Mensaje de error legible o `null`.
  String? get errorMessage => _errorMessage;

  /// Recalcula las métricas de hoy ejecutando las agregaciones en SQLite.
  Future<void> loadTodayAnalytics() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _repository.getTodayAnalytics();
    } catch (e) {
      _errorMessage = 'Error al cargar estadísticas: $e';
      debugPrint('❌ [AnalyticsProvider] $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
