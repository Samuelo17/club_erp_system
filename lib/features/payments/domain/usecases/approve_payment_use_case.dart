import '../repositories/payment_repository.dart';

/// Caso de uso para aprobar un pago digital y marcarlo como CONCILIADO (US-3.1).
class ApprovePaymentUseCase {
  final PaymentRepository _repository;

  const ApprovePaymentUseCase(this._repository);

  Future<void> call(String paymentId) {
    return _repository.approvePayment(paymentId);
  }
}
