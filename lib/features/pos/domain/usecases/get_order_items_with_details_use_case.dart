import '../entities/order_item.dart';
import '../repositories/order_repository.dart';

/// Caso de uso para obtener los ítems de una orden con los nombres de productos (JOIN) (US-3.3).
class GetOrderItemsWithDetailsUseCase {
  final OrderRepository _repository;

  const GetOrderItemsWithDetailsUseCase(this._repository);

  Future<List<OrderItem>> call(String orderId) {
    return _repository.getOrderItemsWithDetails(orderId);
  }
}
