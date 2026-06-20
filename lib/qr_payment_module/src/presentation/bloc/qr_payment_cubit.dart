import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/qr_payment_remote_data_source.dart';
import '../../data/models/order_status.dart';
import '../../data/models/place_order_request.dart';
import '../../data/models/qr_models.dart';
import 'qr_payment_state.dart';

/// Cubit que gestiona el flujo completo de pago QR.
///
/// Flujo:
/// 1. Crear orden pendiente (placeOrderPending)
/// 2. Generar QR (generatePaymentQr)
/// 3. Polling de estado cada [pollingInterval]
/// 4. Completar orden al confirmarse el pago
class QrPaymentCubit extends Cubit<QrPaymentState> {
  final QrPaymentRemoteDataSource _remote;
  final Duration pollingInterval;
  Timer? _pollTimer;

  QrPaymentCubit({
    required QrPaymentRemoteDataSource remoteDataSource,
    this.pollingInterval = const Duration(seconds: 3),
  })  : _remote = remoteDataSource,
        super(const QrPaymentState());

  /// Inicia el flujo completo de pago QR.
  ///
  /// Construye internamente el [PlaceOrderRequestDto] con el mismo formato
  /// que la app principal (cart, metadataMerchant, items enriquecidos, etc.)
  /// y lo envia a [POST /orders/create-pending].
  ///
  /// Si ya existe un QR generado previo (mismo orderId), se reutiliza.
  Future<void> startQrPayment({
    required int merchantId,
    required String customerName,
    required String phoneNumber,
    required String whereEat,
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic>? menuData,
    required double amount,
    String? paymentReferenceOverride,
  }) async {
    // Reutilizar QR existente si el usuario vuelve a elegirlo
    if (state.qrBase64 != null && state.orderId != null) {
      emit(state.copyWith(status: QrPaymentStatus.qrReady));
      _startPolling(merchantId, state.orderId!);
      return;
    }

    emit(state.copyWith(status: QrPaymentStatus.loading));

    try {
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

      // Paso 1: crear orden en estado pendiente
      final orderResponse = await _remote.placeOrderPending(request);
      final orderId = orderResponse.orderId;

      // Paso 2: generar QR de pago
      final qrResponse = await _remote.generatePaymentQr(
        GeneratePaymentQrRequestDto(
          amount: amount,
          merchantId: merchantId,
          orderId: orderId,
        ),
      );

      emit(state.copyWith(
        status: QrPaymentStatus.qrReady,
        orderId: orderId,
        qrBase64: qrResponse.qrBase64,
      ));

      // Paso 3: iniciar polling
      _startPolling(merchantId, orderId);
    } catch (e) {
      debugPrint('[QrPaymentCubit] startQrPayment FAILED: $e');
      emit(state.copyWith(
        status: QrPaymentStatus.failed,
        errorMessage: 'No se pudo generar el QR de pago. Intenta de nuevo.',
      ));
    }
  }

  /// Reinicia el polling si ya hay un QR generado (ej: usuario vuelve a la pantalla).
  void retryPolling(int merchantId) {
    if (state.orderId != null && state.qrBase64 != null) {
      emit(state.copyWith(
        status: QrPaymentStatus.qrReady,
        errorMessage: null,
      ));
      _startPolling(merchantId, state.orderId!);
    }
  }

  /// Cancela el pago y detiene el polling.
  /// Preserva [orderId] y [qrBase64] para poder reanudar con [retryPolling].
  void cancel() {
    _stopPolling();
    emit(state.copyWith(
      status: QrPaymentStatus.cancelled,
      isPolling: false,
    ));
  }

  /// Regresa al estado inicial (limpia todo).
  void reset() {
    _stopPolling();
    emit(const QrPaymentState());
  }

  void _startPolling(int merchantId, int orderId) {
    _stopPolling();
    emit(state.copyWith(isPolling: true));

    _pollTimer = Timer.periodic(pollingInterval, (_) async {
      if (isClosed) return;
      try {
        final statusDto = await _remote.getPaymentStatus(merchantId, orderId);
        if (statusDto.status == OrderStatus.confirmed) {
          _onPaymentConfirmed(orderId);
        } else if (statusDto.status == OrderStatus.failed) {
          _onPaymentFailed();
        }
      } catch (e) {
        // Fallo de red durante polling: silencioso, reintenta en el siguiente tick
        debugPrint('[QrPaymentCubit] Polling error: $e');
      }
    });
  }

  void _onPaymentConfirmed(int orderId) {
    if (isClosed) return;
    _stopPolling();
    _remote.completeOrder(orderId).catchError((_) {});
    emit(state.copyWith(
      status: QrPaymentStatus.success,
      isPolling: false,
    ));
  }

  void _onPaymentFailed() {
    if (isClosed) return;
    _stopPolling();
    emit(state.copyWith(
      status: QrPaymentStatus.failed,
      errorMessage: 'El pago fue rechazado o expiró. Por favor intenta de nuevo.',
      orderId: null,
      qrBase64: null,
      isPolling: false,
    ));
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
