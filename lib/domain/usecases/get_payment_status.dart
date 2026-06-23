import '../entities/order_status.dart';
import '../repositories/qr_payment_repository.dart';

/// Consulta el estado actual de un pago QR.
class GetPaymentStatusUseCase {
  final QrPaymentRepository _repository;

  GetPaymentStatusUseCase(this._repository);

  Future<OrderStatus> call(int merchantId, int orderId) =>
      _repository.getPaymentStatus(merchantId, orderId);
}
