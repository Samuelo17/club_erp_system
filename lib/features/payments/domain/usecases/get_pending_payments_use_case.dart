import '../entities/payment.dart';
import '../repositories/payment_repository.dart';

/// Caso de uso para obtener los pagos pendientes de validación bancaria (US-3.1).
class GetPendingPaymentsUseCase {
  final PaymentRepository _repository;

  const GetPendingPaymentsUseCase(this._repository);

  Future<List<Payment>> call() {
    return _repository.getPendingPayments();
  }
}
