import 'package:dio/dio.dart';
import '../models/place_order_request.dart';
import '../models/qr_models.dart';
import '../models/update_order_request.dart';

/// Excepcion generica de servidor.
class ServerException implements Exception {
  final String? message;
  ServerException([this.message]);

  @override
  String toString() => 'ServerException: ${message ?? 'Error del servidor'}';
}

/// Interface del data source remoto para operaciones QR.
abstract class QrPaymentRemoteDataSource {
  /// Crea un pedido en estado pendiente.
  /// Endpoint: POST /orders/create-pending
  Future<PlaceOrderResponseDto> placeOrderPending(PlaceOrderRequestDto request);

  /// Genera el QR de pago para un pedido existente.
  /// Endpoint: POST /payments/qr/generate-payment
  Future<GeneratePaymentQrResponseDto> generatePaymentQr(
    GeneratePaymentQrRequestDto request,
  );

  /// Consulta el estado del pago QR.
  /// Endpoint: GET /payments/qr/status/:merchantId/:orderId
  Future<PaymentStatusDto> getPaymentStatus(int merchantId, int orderId);

  /// Actualiza datos de un pedido existente (nombre, nit, etc).
  /// Endpoint: PUT /orders/{id}
  Future<void> updateOrder(int orderId, UpdateOrderRequestDto request);

  /// Completa un pedido pendiente.
  /// Endpoint: POST /orders/complete/:id
  Future<void> completeOrder(int orderId);
}

class QrPaymentRemoteDataSourceImpl implements QrPaymentRemoteDataSource {
  final Dio _dio;

  QrPaymentRemoteDataSourceImpl(this._dio);

  @override
  Future<PlaceOrderResponseDto> placeOrderPending(
    PlaceOrderRequestDto request,
  ) async {
    try {
      final response = await _dio.post('/orders/create-pending', data: request.toJson());
      return PlaceOrderResponseDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw ServerException('placeOrderPending failed: $e');
    }
  }

  @override
  Future<GeneratePaymentQrResponseDto> generatePaymentQr(
    GeneratePaymentQrRequestDto request,
  ) async {
    try {
      final response = await _dio.post(
        '/payments/qr/generate-payment',
        data: request.toJson(),
      );
      return GeneratePaymentQrResponseDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw ServerException('generatePaymentQr failed: $e');
    }
  }

  @override
  Future<PaymentStatusDto> getPaymentStatus(
    int merchantId,
    int orderId,
  ) async {
    try {
      final response =
          await _dio.get('/payments/qr/status/$merchantId/$orderId');
      return PaymentStatusDto.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e) {
      throw ServerException('getPaymentStatus failed: $e');
    }
  }

  @override
  Future<void> updateOrder(int orderId, UpdateOrderRequestDto request) async {
    try {
      await _dio.put('/orders/$orderId', data: request.toJson());
    } catch (e) {
      throw ServerException('updateOrder failed: $e');
    }
  }

  @override
  Future<void> completeOrder(int orderId) async {
    try {
      await _dio.post('/orders/complete/$orderId');
    } catch (e) {
      throw ServerException('completeOrder failed: $e');
    }
  }
}
