import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/usecases/complete_order.dart';
import '../../domain/usecases/get_payment_status.dart';
import '../../domain/usecases/start_qr_payment.dart';
import 'qr_payment_state.dart';

/// Cubit que gestiona el flujo completo de pago QR.
///
/// Flujo:
/// 1. Crear orden pendiente + generar QR (StartQrPaymentUseCase)
/// 2. Polling de estado cada [pollingInterval] (GetPaymentStatusUseCase)
/// 3. Completar orden al confirmarse el pago (CompleteOrderUseCase)
class QrPaymentCubit extends Cubit<QrPaymentState> {
  final StartQrPaymentUseCase _startQrPayment;
  final GetPaymentStatusUseCase _getPaymentStatus;
  final CompleteOrderUseCase _completeOrder;
  final Duration pollingInterval;
  Timer? _pollTimer;

  QrPaymentCubit({
    required StartQrPaymentUseCase startQrPayment,
    required GetPaymentStatusUseCase getPaymentStatus,
    required CompleteOrderUseCase completeOrder,
    this.pollingInterval = const Duration(seconds: 3),
  })  : _startQrPayment = startQrPayment,
        _getPaymentStatus = getPaymentStatus,
        _completeOrder = completeOrder,
        super(const QrPaymentState());

  /// Inicia el flujo completo de pago QR.
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
      final order = await _startQrPayment(
        merchantId: merchantId,
        customerName: customerName,
        phoneNumber: phoneNumber,
        whereEat: whereEat,
        cartItems: cartItems,
        menuData: menuData,
        amount: amount,
        paymentReferenceOverride: paymentReferenceOverride,
      );

      emit(state.copyWith(
        status: QrPaymentStatus.qrReady,
        orderId: order.orderId,
        qrBase64: order.qrBase64,
      ));

      _startPolling(merchantId, order.orderId);
    } catch (e) {
      debugPrint('[QrPaymentCubit] startQrPayment FAILED: $e');
      emit(state.copyWith(
        status: QrPaymentStatus.failed,
        errorMessage: 'No se pudo generar el QR de pago. Intenta de nuevo.',
      ));
    }
  }

  /// Reinicia el polling si ya hay un QR generado.
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
        final status = await _getPaymentStatus(merchantId, orderId);
        if (status == OrderStatus.confirmed) {
          _onPaymentConfirmed(orderId);
        } else if (status == OrderStatus.failed) {
          _onPaymentFailed();
        }
      } catch (e) {
        debugPrint('[QrPaymentCubit] Polling error: $e');
      }
    });
  }

  void _onPaymentConfirmed(int orderId) {
    if (isClosed) return;
    _stopPolling();
    _completeOrder(orderId).catchError((_) {});
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
