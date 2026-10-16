import 'top_product_item.dart';

/// DTO / Entidad de dominio que representa las métricas y KPIs del turno actual (US-3.2).
class DailyAnalyticsSummary {
  /// Total vendido hoy en USD sumando el monto de las órdenes completadas.
  final double totalUsd;

  /// Total recaudado hoy en VES sumando los pagos en Bolívares.
  final double totalVes;

  /// Cantidad total de órdenes procesadas en el día de hoy.
  final int ordersCount;

  /// Top 3 de productos más vendidos en el día actual con sus cantidades.
  final List<TopProductItem> topProducts;

  const DailyAnalyticsSummary({
    required this.totalUsd,
    required this.totalVes,
    required this.ordersCount,
    required this.topProducts,
  });

  /// Resumen vacío para inicialización o estado sin datos.
  const DailyAnalyticsSummary.empty()
      : totalUsd = 0.0,
        totalVes = 0.0,
        ordersCount = 0,
        topProducts = const [];
}
