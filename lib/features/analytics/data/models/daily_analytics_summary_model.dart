import '../../domain/entities/daily_analytics_summary.dart';
import '../../domain/entities/top_product_item.dart';

/// Modelo de datos que extiende [DailyAnalyticsSummary].
class DailyAnalyticsSummaryModel extends DailyAnalyticsSummary {
  const DailyAnalyticsSummaryModel({
    required super.totalUsd,
    required super.totalVes,
    required super.ordersCount,
    required super.topProducts,
  });

  factory DailyAnalyticsSummaryModel.fromAggregates({
    required double totalUsd,
    required double totalVes,
    required int ordersCount,
    required List<TopProductItem> topProducts,
  }) {
    return DailyAnalyticsSummaryModel(
      totalUsd: totalUsd,
      totalVes: totalVes,
      ordersCount: ordersCount,
      topProducts: topProducts,
    );
  }
}
