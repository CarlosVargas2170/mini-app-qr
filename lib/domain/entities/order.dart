import 'order_status.dart';

/// Entidad de dominio que representa una orden de pago.
class Order {
  final int orderId;
  final String? qrBase64;
  final OrderStatus status;
  final int? dailyOrderNumber;
  final String? storeName;
  final String? provider;
  final String? externalId;

  const Order({
    required this.orderId,
    this.qrBase64,
    this.status = OrderStatus.pending,
    this.dailyOrderNumber,
    this.storeName,
    this.provider,
    this.externalId,
  });
}
