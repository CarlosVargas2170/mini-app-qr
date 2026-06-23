import '../repositories/qr_payment_repository.dart';

/// Marca una orden como completada.
class CompleteOrderUseCase {
  final QrPaymentRepository _repository;

  CompleteOrderUseCase(this._repository);

  Future<void> call(int orderId) => _repository.completeOrder(orderId);
}
