import '../entities/order.dart';
import '../repositories/order_repository.dart';

/// Caso de uso para obtener las órdenes pagadas/completadas de la fecha de hoy (US-3.3).
class GetTodayCompletedOrdersUseCase {
  final OrderRepository _repository;

  const GetTodayCompletedOrdersUseCase(this._repository);

  Future<List<Order>> call() {
    return _repository.getTodayCompletedOrders();
  }
}
