import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/payment_counter.dart';
import '../../core/services/payment_polling_status.dart';
import '../../core/services/ui_command_bus.dart';
import '../bloc/qr_payment_cubit.dart';
import '../bloc/qr_payment_state.dart';
import 'product_qr_panel.dart';
import '../../core/config/app_settings.dart';

/// Entrada de caché para un QR generado.
///
/// Guarda [merchantId] y [amount] junto al QR para que el polling/reuso
/// no mezcle datos entre merchants o productos.
class _CachedQr {
  final String qrBase64;
  final int orderId;
  final int merchantId;
  final double amount;
  final DateTime createdAt;

  const _CachedQr({
    required this.qrBase64,
    required this.orderId,
    required this.merchantId,
    required this.amount,
    required this.createdAt,
  });

  /// Un QR se considera expirado según [AppSettings.qrExpirationMinutes].
  bool get isExpired =>
      DateTime.now().difference(createdAt).inMinutes >=
      AppSettings.qrExpirationMinutes;
}

/// Clave de caché compuesta: evita colisiones si dos merchants comparten productId.
String _cacheKey(int merchantId, int productId) => '${merchantId}_$productId';

/// Wrapper que gestiona el ciclo de vida del [QrPaymentCubit],
/// la caché en memoria de QRs por producto, y el flujo post-pago.
///
/// Flujo (polling manual por operador):
/// ```
/// init → generar/cachear QR (SIN polling) → mostrar QR
///              ↓
///   operador: UiCommand.startPaymentPolling
///              ↓
///   mostrar UI "Esperando confirmación..." + Timer.periodic
///              ↓
///   SUCCESS → audio + éxito 5s → invalidar caché → regenerar QR (sin poll)
/// ```
///
/// Usa [key: ValueKey(productId)] en el padre para forzar recreación
/// al cambiar de producto.
class ProductQrPanelWrapper extends StatefulWidget {
  final int productId;
  final double price;
  final String name;
  final String description;
  final String urlImage;
  final int merchantId;
  final String merchantName;

  const ProductQrPanelWrapper({
    super.key,
    required this.productId,
    required this.price,
    required this.name,
    required this.description,
    required this.urlImage,
    required this.merchantId,
    required this.merchantName,
  });

  @override
  State<ProductQrPanelWrapper> createState() => _ProductQrPanelWrapperState();
}

class _ProductQrPanelWrapperState extends State<ProductQrPanelWrapper> {
  /// Caché estática compartida entre todas las instancias del wrapper.
  /// Key: "{merchantId}_{productId}".
  static final Map<String, _CachedQr> _cache = {};

  /// Tiempo que se muestra la pantalla de éxito antes del auto-reset.
  static const _successDisplayDuration = Duration(seconds: 5);

  QrPaymentCubit? _cubit;
  StreamSubscription<UiCommand>? _commandSub;
  bool _isSuccess = false;
  Timer? _resetTimer;

  /// Si el operador pidió polling antes de que el QR estuviera listo.
  bool _pendingPollRequest = false;

  String get _key => _cacheKey(widget.merchantId, widget.productId);

  @override
  void initState() {
    super.initState();
    _cleanExpiredCache();
    _commandSub = UiCommandBus.stream.listen(_onUiCommand);
    _bootstrapQr();
  }

  /// Elimina entradas expiradas del caché.
  void _cleanExpiredCache() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  /// Prepara el QR del producto: cache hit o generación sin polling.
  void _bootstrapQr() {
    final cached = _cache[_key];
    // Solo reutiliza si merchant y monto siguen coincidiendo con el producto actual.
    if (cached != null &&
        !cached.isExpired &&
        cached.merchantId == widget.merchantId &&
        cached.amount == widget.price) {
      _cubit?.close();
      _cubit = sl.qrPaymentCubit();
      // Restaura el QR cacheado sin iniciar polling.
      _cubit!.restoreQr(
        orderId: cached.orderId,
        qrBase64: cached.qrBase64,
      );
      // restore ocurre antes del BlocConsumer: publicar a mano.
      _publishPollingStatus(_cubit!.state);
      return;
    }

    _cache.remove(_key);
    _startPayment(autoPoll: false);
  }

  /// Crea un [QrPaymentCubit] e inicia generación de orden + QR.
  void _startPayment({required bool autoPoll}) {
    _cubit?.close();
    _cubit = sl.qrPaymentCubit();

    final cartItems = [
      {
        'name': widget.name,
        'quantity': 1,
        'price': widget.price,
      },
    ];

    final menuData = {
      'merchantName': widget.merchantName,
      'categories': [
        {
          'products': [
            {
              'id': widget.productId,
              'name': widget.name,
              'price': widget.price,
              'urlImage': widget.urlImage,
              'description': widget.description,
            },
          ],
        },
      ],
    };

    debugPrint(
      '[ProductQrPanel] Generando QR productId=${widget.productId} '
      'merchantId=${widget.merchantId} amount=${widget.price}',
    );

    unawaited(
      _cubit!
          .startQrPayment(
        merchantId: widget.merchantId,
        amount: widget.price,
        customerName: AppSettings.customerName,
        phoneNumber: '',
        whereEat: 'dineIn',
        cartItems: cartItems,
        menuData: menuData,
        autoPoll: autoPoll,
      )
          .then((_) {
        if (!mounted) return;
        // Si el operador pidió polling mientras se generaba el QR.
        if (_pendingPollRequest &&
            _cubit != null &&
            _cubit!.state.orderId != null &&
            _cubit!.state.qrBase64 != null) {
          _pendingPollRequest = false;
          _beginPollingWithCorrectMerchant();
        }
      }),
    );
  }

  /// Inicia polling usando el merchant del QR cacheado (si existe) o del producto.
  void _beginPollingWithCorrectMerchant({int? orderId, String? qrBase64}) {
    final cached = _cache[_key];
    final merchantId = cached?.merchantId ?? widget.merchantId;
    final resolvedOrderId = orderId ?? cached?.orderId ?? _cubit?.state.orderId;
    final resolvedQr = qrBase64 ?? cached?.qrBase64 ?? _cubit?.state.qrBase64;

    debugPrint(
      '[ProductQrPanel] beginPolling productId=${widget.productId} '
      'merchantId=$merchantId orderId=$resolvedOrderId',
    );

    _cubit?.beginPolling(
      merchantId,
      orderId: resolvedOrderId,
      qrBase64: resolvedQr,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Comandos del operador (remote-control)
  // ─────────────────────────────────────────────────────────────

  void _onUiCommand(UiCommand cmd) {
    if (!mounted) return;

    switch (cmd) {
      case UiCommand.startPaymentPolling:
        _activatePolling();
        break;
      case UiCommand.stopPaymentPolling:
      case UiCommand.cancelPayment:
      case UiCommand.showAttract:
      case UiCommand.showIdle:
        _deactivatePolling();
        break;
      default:
        break;
    }
  }

  /// Activa el polling real y la UI "Esperando confirmación...".
  void _activatePolling() {
    if (_isSuccess) {
      debugPrint('[ProductQrPanel] startPaymentPolling ignorado: ya en éxito');
      return;
    }

    final cubit = _cubit;
    if (cubit == null) {
      debugPrint(
          '[ProductQrPanel] startPaymentPolling: sin cubit, regenerando QR con poll');
      _pendingPollRequest = true;
      _startPayment(autoPoll: true);
      setState(() {});
      return;
    }

    final state = cubit.state;

    if (state.status == QrPaymentStatus.loading ||
        state.status == QrPaymentStatus.initial) {
      debugPrint(
          '[ProductQrPanel] startPaymentPolling: QR aún cargando, se activará al estar listo');
      _pendingPollRequest = true;
      return;
    }

    if (state.orderId == null || state.qrBase64 == null) {
      // Fallo previo o sin QR: regenerar e iniciar poll.
      debugPrint(
          '[ProductQrPanel] startPaymentPolling: sin orderId/QR, regenerando con poll');
      _pendingPollRequest = false;
      _startPayment(autoPoll: true);
      setState(() {});
      return;
    }

    if (state.isPolling) {
      debugPrint('[ProductQrPanel] startPaymentPolling: ya está activo');
      return;
    }

    debugPrint(
        '[ProductQrPanel] Activando polling manual orderId=${state.orderId}');
    _beginPollingWithCorrectMerchant();
  }

  /// Detiene el polling sin borrar el QR.
  /// No toca la UI si ya se mostró el pago exitoso.
  void _deactivatePolling() {
    if (_isSuccess) return;
    _pendingPollRequest = false;
    _cubit?.stopPollingOnly();
    // stopPollingOnly emite estado; el listener publicará. Por si no hay cubit:
    final cubit = _cubit;
    if (cubit != null) {
      _publishPollingStatus(cubit.state);
    } else {
      PaymentPollingStatus().setIdle();
    }
  }

  @override
  void dispose() {
    _commandSub?.cancel();
    _resetTimer?.cancel();
    _cubit?.close();
    // Si este panel era el activo, limpia el estado expuesto al remote-control.
    final status = PaymentPollingStatus();
    if (status.productId == null || status.productId == widget.productId) {
      status.setIdle();
    }
    super.dispose();
  }

  /// Publica el estado de polling para el remote-control.
  void _publishPollingStatus(QrPaymentState state) {
    final pub = PaymentPollingStatus();
    if (state.status == QrPaymentStatus.success || _isSuccess) {
      pub.setSuccess(
        productId: widget.productId,
        merchantId: widget.merchantId,
        orderId: state.orderId,
        amount: widget.price,
        productName: widget.name,
      );
      return;
    }
    if (state.status == QrPaymentStatus.failed) {
      pub.setFailed(
        productId: widget.productId,
        merchantId: widget.merchantId,
        orderId: state.orderId,
      );
      return;
    }
    if (state.isPolling &&
        state.status == QrPaymentStatus.qrReady &&
        state.orderId != null) {
      pub.setPolling(
        productId: widget.productId,
        merchantId: widget.merchantId,
        orderId: state.orderId!,
        amount: widget.price,
        productName: widget.name,
      );
      return;
    }
    // QR listo o cargando, sin poll activo.
    pub.setWaiting(
      productId: widget.productId,
      merchantId: widget.merchantId,
      orderId: state.orderId,
      amount: widget.price,
      productName: widget.name,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── Éxito (overlay temporal) ──
    if (_isSuccess) {
      return ProductQrPanel(
        price: widget.price,
        isSuccess: true,
      );
    }

    final cubit = _cubit;
    if (cubit == null) {
      return ProductQrPanel(
        price: widget.price,
        isLoading: true,
      );
    }

    return BlocProvider.value(
      value: cubit,
      child: BlocConsumer<QrPaymentCubit, QrPaymentState>(
        listener: _onCubitState,
        builder: (context, state) => _buildFromState(state),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Listener del cubit
  // ─────────────────────────────────────────────────────────────

  void _onCubitState(BuildContext context, QrPaymentState state) {
    if (!mounted) return;

    // ── QR listo: cachear solo si es una orden nueva (no resetear TTL al poll) ──
    if (state.status == QrPaymentStatus.qrReady &&
        state.qrBase64 != null &&
        state.orderId != null) {
      final existing = _cache[_key];
      if (existing == null || existing.orderId != state.orderId) {
        _cache[_key] = _CachedQr(
          qrBase64: state.qrBase64!,
          orderId: state.orderId!,
          merchantId: widget.merchantId,
          amount: widget.price,
          createdAt: DateTime.now(),
        );
        debugPrint(
          '[ProductQrPanel] Cache QR key=$_key orderId=${state.orderId} '
          'merchantId=${widget.merchantId} amount=${widget.price}',
        );
      }

      // Polling pendiente solicitado mientras se generaba el QR.
      if (_pendingPollRequest && !state.isPolling) {
        _pendingPollRequest = false;
        debugPrint('[ProductQrPanel] QR listo + poll pendiente → beginPolling');
        _beginPollingWithCorrectMerchant();
      }
    }

    // ── Pago exitoso ──
    if (state.status == QrPaymentStatus.success) {
      _onPaymentSuccess();
    }

    // ── Pago fallido o expirado: invalidar caché ──
    if (state.status == QrPaymentStatus.failed) {
      _cache.remove(_key);
    }

    // Siempre sincroniza estado hacia el remote-control.
    _publishPollingStatus(state);
  }

  // ─────────────────────────────────────────────────────────────
  // Manejo de éxito
  // ─────────────────────────────────────────────────────────────

  void _onPaymentSuccess() {
    if (_isSuccess) return; // Evitar doble ejecución

    _pendingPollRequest = false;
    _cache.remove(_key);

    PaymentCounter().increment(
      amount: widget.price,
      productId: widget.productId,
      productName: widget.name,
      merchantId: widget.merchantId,
    );
    AudioService.playThanks();

    setState(() => _isSuccess = true);
    PaymentPollingStatus().setSuccess(
      productId: widget.productId,
      merchantId: widget.merchantId,
      orderId: _cubit?.state.orderId,
      amount: widget.price,
      productName: widget.name,
    );

    // Después de mostrar el éxito, reiniciar para permitir nueva compra
    _resetTimer?.cancel();
    _resetTimer = Timer(_successDisplayDuration, _resetForNewPurchase);
  }

  /// Cierra el cubit viejo, limpia caché y genera un QR fresco (sin polling).
  void _resetForNewPurchase() {
    if (!mounted) return;

    _cache.remove(_key);
    _cubit?.close();
    _cubit = null;
    _pendingPollRequest = false;

    setState(() {
      _isSuccess = false;
    });

    PaymentPollingStatus().setWaiting(
      productId: widget.productId,
      merchantId: widget.merchantId,
      amount: widget.price,
      productName: widget.name,
    );

    _startPayment(autoPoll: false);
  }

  // ─────────────────────────────────────────────────────────────
  // Builder desde estado del cubit
  // ─────────────────────────────────────────────────────────────

  Widget _buildFromState(QrPaymentState state) {
    return ProductQrPanel(
      price: widget.price,
      qrBase64: state.qrBase64,
      isLoading: state.status == QrPaymentStatus.loading ||
          state.status == QrPaymentStatus.initial,
      // Solo se muestra la UI de polling cuando el operador lo activó.
      isPolling: state.isPolling && state.status == QrPaymentStatus.qrReady,
      isSuccess: state.status == QrPaymentStatus.success,
      errorMessage:
          state.status == QrPaymentStatus.failed ? state.errorMessage : null,
    );
  }
}
