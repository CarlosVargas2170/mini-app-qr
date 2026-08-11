import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/usecases/complete_order.dart';
import '../../domain/usecases/get_payment_status.dart';
import '../../domain/usecases/get_product.dart';
import '../../domain/usecases/start_qr_payment.dart';
import '../../domain/usecases/update_order.dart';
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
  final UpdateOrderUseCase _updateOrder;
  final CompleteOrderUseCase _completeOrder;
  final GetProductUseCase _getProduct;
  final Duration pollingInterval;
  Timer? _pollTimer;

  QrPaymentCubit({
    required StartQrPaymentUseCase startQrPayment,
    required GetPaymentStatusUseCase getPaymentStatus,
    required UpdateOrderUseCase updateOrder,
    required CompleteOrderUseCase completeOrder,
    required GetProductUseCase getProduct,
    this.pollingInterval = const Duration(seconds: 3),
  })  : _startQrPayment = startQrPayment,
        _getPaymentStatus = getPaymentStatus,
        _updateOrder = updateOrder,
        _completeOrder = completeOrder,
        _getProduct = getProduct,
        super(const QrPaymentState());

  /// Inicia el flujo completo de pago QR.
  ///
  /// Si [autoPoll] es `false`, solo genera la orden + QR y deja el polling
  /// para activarlo después con [beginPolling] (flujo home / operador).
  ///
  /// Antes de generar la orden, valida que el producto siga existiendo
  /// consultando la API con [productId]. Si el producto fue eliminado,
  /// emite [QrPaymentStatus.failed] con un mensaje descriptivo.
  /// Si el precio cambió, usa el precio actualizado.
  Future<void> startQrPayment({
    required int merchantId,
    required int productId,
    required String customerName,
    required String phoneNumber,
    required String whereEat,
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic>? menuData,
    required double amount,
    String? paymentReferenceOverride,
    bool autoPoll = true,
  }) async {
    // Reutilizar QR existente si el usuario vuelve a elegirlo
    if (state.qrBase64 != null && state.orderId != null) {
      emit(state.copyWith(status: QrPaymentStatus.qrReady));
      if (autoPoll) {
        _startPolling(merchantId, state.orderId!);
      }
      return;
    }

    emit(state.copyWith(status: QrPaymentStatus.loading));

    try {
      // ── Validación pre-pago: verificar que el producto siga existiendo ──
      double validatedAmount = amount;

      try {
        final freshProduct = await _getProduct(merchantId, productId);
        debugPrint('[QrPaymentCubit] Producto validado: "${freshProduct.name}" '
            'precio API=${freshProduct.price}, precio local=$amount');

        if (freshProduct.price != amount) {
          debugPrint(
              '[QrPaymentCubit] ⚠️ Precio desactualizado: local=$amount → API=${freshProduct.price}. '
              'Usando precio actualizado.');
          validatedAmount = freshProduct.price;

          // Actualizar cartItems con el precio fresco
          for (final item in cartItems) {
            item['price'] = freshProduct.price;
          }

          // Actualizar menuData con el precio fresco
          final menu = menuData;
          if (menu != null) {
            final categories = menu['categories'] as List?;
            if (categories != null && categories.isNotEmpty) {
              final firstCategory = categories.first as Map?;
              final products = firstCategory?['products'] as List?;
              if (products != null && products.isNotEmpty) {
                final firstProduct = products.first as Map?;
                if (firstProduct != null) {
                  firstProduct['price'] = freshProduct.price;
                  firstProduct['name'] = freshProduct.name;
                  firstProduct['urlImage'] = freshProduct.urlImage;
                  firstProduct['description'] = freshProduct.description;
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[QrPaymentCubit] ❌ Producto $productId no encontrado: $e');
        emit(state.copyWith(
          status: QrPaymentStatus.failed,
          errorMessage:
              'Este producto ya no está disponible.\nPor favor elige otro.',
        ));
        return;
      }

      // ── Crear orden y generar QR ──
      final order = await _startQrPayment(
        merchantId: merchantId,
        customerName: customerName,
        phoneNumber: phoneNumber,
        whereEat: whereEat,
        cartItems: cartItems,
        menuData: menuData,
        amount: validatedAmount,
        paymentReferenceOverride: paymentReferenceOverride,
      );

      emit(state.copyWith(
        status: QrPaymentStatus.qrReady,
        orderId: order.orderId,
        qrBase64: order.qrBase64,
      ));

      if (autoPoll) {
        _startPolling(merchantId, order.orderId);
      }
    } catch (e) {
      debugPrint('[QrPaymentCubit] startQrPayment FAILED: $e');
      emit(state.copyWith(
        status: QrPaymentStatus.failed,
        errorMessage: 'No se pudo generar el QR de pago. Intenta de nuevo.',
      ));
    }
  }

  /// Restaura un QR/orden existentes en el estado sin iniciar polling.
  ///
  /// Útil para cache hit en home: mostrar el QR y dejar el poll al operador.
  void restoreQr({
    required int orderId,
    required String qrBase64,
  }) {
    _stopPolling();
    emit(state.copyWith(
      status: QrPaymentStatus.qrReady,
      orderId: orderId,
      qrBase64: qrBase64,
      isPolling: false,
      errorMessage: null,
    ));
  }

  /// Inicia (o reinicia) el polling del pago.
  ///
  /// Puede usar [orderId]/[qrBase64] externos (p. ej. desde caché de home)
  /// o los del estado actual del cubit.
  void beginPolling(
    int merchantId, {
    int? orderId,
    String? qrBase64,
  }) {
    final resolvedOrderId = orderId ?? state.orderId;
    final resolvedQr = qrBase64 ?? state.qrBase64;

    if (resolvedOrderId == null) {
      debugPrint(
          '[QrPaymentCubit] beginPolling ignorado: no hay orderId disponible');
      return;
    }

    emit(state.copyWith(
      status: QrPaymentStatus.qrReady,
      orderId: resolvedOrderId,
      qrBase64: resolvedQr,
      errorMessage: null,
    ));
    _startPolling(merchantId, resolvedOrderId);
  }

  /// Reinicia el polling si ya hay un QR generado.
  void retryPolling(int merchantId) {
    beginPolling(merchantId);
  }

  /// Detiene el polling sin cancelar la orden ni limpiar el QR.
  void stopPollingOnly() {
    _stopPolling();
    if (state.isPolling) {
      emit(state.copyWith(isPolling: false));
    }
  }

  /// Cancela el pago y detiene el polling.
  ///
  /// Si el pago ya fue exitoso, solo detiene el timer y **no** sobrescribe
  /// el estado (evita que la UI de "CANCELADO" pise el de "PAGO EXITOSO").
  void cancel() {
    _stopPolling();
    if (state.status == QrPaymentStatus.success) {
      debugPrint('[QrPaymentCubit] cancel() ignorado: pago ya exitoso');
      return;
    }
    if (state.status == QrPaymentStatus.cancelled) {
      return;
    }
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

  /// Actualiza datos del cliente en la orden actual.
  /// Solo funciona si hay un orderId activo.
  Future<void> updateOrderDetails({
    String? customerName,
    String? nit,
    String? businessName,
    String? phoneNumber,
  }) async {
    final orderId = state.orderId;
    if (orderId == null) {
      debugPrint(
          '[QrPaymentCubit] updateOrderDetails ignorado: no hay orderId');
      return;
    }

    try {
      debugPrint('[QrPaymentCubit] Actualizando orden $orderId...');
      await _updateOrder(
        orderId: orderId,
        customerName: customerName,
        nit: nit,
        businessName: businessName,
        phoneNumber: phoneNumber,
      );
      debugPrint('[QrPaymentCubit] Orden $orderId actualizada OK');
    } catch (e) {
      debugPrint('[QrPaymentCubit] updateOrderDetails FAILED: $e');
    }
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
      errorMessage:
          'El pago fue rechazado o expiró. Por favor intenta de nuevo.',
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
