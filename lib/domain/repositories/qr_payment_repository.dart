import '../entities/order.dart';
import '../entities/order_status.dart';

/// Contrato del repositorio de pagos QR.
abstract class QrPaymentRepository {
  /// Crea una orden pendiente, genera el QR y retorna la orden enriquecida.
  Future<Order> startQrPayment({
    required int merchantId,
    required String customerName,
    required String phoneNumber,
    required String whereEat,
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic>? menuData,
    required double amount,
    String? paymentReferenceOverride,
  });

  /// Consulta el estado actual del pago.
  Future<OrderStatus> getPaymentStatus(int merchantId, int orderId);

  /// Actualiza datos del cliente en la orden.
  Future<void> updateOrder({
    required int orderId,
    String? customerName,
    String? nit,
    String? businessName,
    String? phoneNumber,
  });

  /// Marca la orden como completada.
  Future<void> completeOrder(int orderId);
}
