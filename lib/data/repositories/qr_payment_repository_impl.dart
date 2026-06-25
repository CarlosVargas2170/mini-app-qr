import '../../domain/entities/order.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/repositories/qr_payment_repository.dart';
import '../datasources/qr_payment_remote_data_source.dart';
import '../models/place_order_request.dart';
import '../models/qr_models.dart';
import '../models/update_order_request.dart';

class QrPaymentRepositoryImpl implements QrPaymentRepository {
  final QrPaymentRemoteDataSource _remote;

  QrPaymentRepositoryImpl(this._remote);

  @override
  Future<Order> startQrPayment({
    required int merchantId,
    required String customerName,
    required String phoneNumber,
    required String whereEat,
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic>? menuData,
    required double amount,
    String? paymentReferenceOverride,
  }) async {
    final request = PlaceOrderRequestDto(
      merchantId: merchantId,
      customerName: customerName.trim().isNotEmpty ? customerName.trim() : 'Cliente',
      phoneNumber: phoneNumber,
      whereEat: whereEat.isNotEmpty ? whereEat : 'dineIn',
      paymentMethodType: 'qr',
      cartItems: cartItems,
      menuData: menuData,
      paymentReferenceOverride: paymentReferenceOverride,
    );

    final orderResponse = await _remote.placeOrderPending(request);
    final orderId = orderResponse.orderId;

    print('[QR_REPO] Orden creada: orderId=$orderId, amount=$amount, merchantId=$merchantId');

    final qrRequest = GeneratePaymentQrRequestDto(
      amount: amount,
      merchantId: merchantId,
      orderId: orderId,
    );
    print('[QR_REPO] Generando QR con body: ${qrRequest.toJson()}');

    final qrResponse = await _remote.generatePaymentQr(qrRequest);

    return Order(
      orderId: orderId,
      qrBase64: qrResponse.qrBase64,
      status: OrderStatus.pending,
      dailyOrderNumber: orderResponse.dailyOrderNumber,
      storeName: orderResponse.storeName,
      provider: orderResponse.provider,
      externalId: orderResponse.externalId,
    );
  }

  @override
  Future<OrderStatus> getPaymentStatus(int merchantId, int orderId) async {
    final dto = await _remote.getPaymentStatus(merchantId, orderId);
    return dto.status;
  }

  @override
  Future<void> updateOrder({
    required int orderId,
    String? customerName,
    String? nit,
    String? businessName,
    String? phoneNumber,
  }) async {
    final request = UpdateOrderRequestDto(
      customerName: customerName,
      nit: nit,
      businessName: businessName,
      phoneNumber: phoneNumber,
    );
    await _remote.updateOrder(orderId, request);
  }

  @override
  Future<void> completeOrder(int orderId) async {
    await _remote.completeOrder(orderId);
  }
}
