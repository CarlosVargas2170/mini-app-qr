import '../repositories/qr_payment_repository.dart';

/// Actualiza datos del cliente en una orden existente.
///
/// Campos opcionales: customerName, nit, businessName, phoneNumber.
/// Solo se envian los campos que no son null ni vacios.
class UpdateOrderUseCase {
  final QrPaymentRepository _repository;

  UpdateOrderUseCase(this._repository);

  Future<void> call({
    required int orderId,
    String? customerName,
    String? nit,
    String? businessName,
    String? phoneNumber,
  }) {
    return _repository.updateOrder(
      orderId: orderId,
      customerName: customerName,
      nit: nit,
      businessName: businessName,
      phoneNumber: phoneNumber,
    );
  }
}
