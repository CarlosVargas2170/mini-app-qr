import '../entities/order.dart';
import '../repositories/qr_payment_repository.dart';

/// Inicia el flujo completo de pago QR (crear orden + generar QR).
class StartQrPaymentUseCase {
  final QrPaymentRepository _repository;

  StartQrPaymentUseCase(this._repository);

  Future<Order> call({
    required int merchantId,
    required String customerName,
    required String phoneNumber,
    required String whereEat,
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic>? menuData,
    required double amount,
    String? paymentReferenceOverride,
  }) =>
      _repository.startQrPayment(
        merchantId: merchantId,
        customerName: customerName,
        phoneNumber: phoneNumber,
        whereEat: whereEat,
        cartItems: cartItems,
        menuData: menuData,
        amount: amount,
        paymentReferenceOverride: paymentReferenceOverride,
      );
}
