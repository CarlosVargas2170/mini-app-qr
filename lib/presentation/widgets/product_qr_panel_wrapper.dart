import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/service_locator.dart';
import '../../core/services/audio_service.dart';
import '../bloc/qr_payment_cubit.dart';
import '../bloc/qr_payment_state.dart';
import 'product_qr_panel.dart';

/// Entrada de caché para un QR generado.
class _CachedQr {
  final String qrBase64;
  final int orderId;
  final DateTime createdAt;

  const _CachedQr({
    required this.qrBase64,
    required this.orderId,
    required this.createdAt,
  });

  /// Un QR se considera expirado después de 3 minutos.
  bool get isExpired => DateTime.now().difference(createdAt).inMinutes >= 3;
}

/// Wrapper que gestiona el ciclo de vida del [QrPaymentCubit],
/// la caché en memoria de QRs por producto, y el flujo post-pago.
///
/// Flujo completo:
/// ```
/// CACHE HIT → mostrar QR cacheado → polling → SUCCESS → audio + éxito 5s
///                                                           ↓
///                                                    invalidar caché
///                                                           ↓
///                                                     regenerar QR
///
/// CACHE MISS → crear cubit → generar orden+QR → mostrar QR → polling
///                ↑                                            ↓
///                └──────────── (auto-reset) ←────────── SUCCESS/FAILED
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
  static final Map<int, _CachedQr> _cache = {};

  /// Tiempo que se muestra la pantalla de éxito antes del auto-reset.
  static const _successDisplayDuration = Duration(seconds: 5);

  QrPaymentCubit? _cubit;
  bool _cacheHit = false;
  bool _isSuccess = false;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _cleanExpiredCache();

    final cached = _cache[widget.productId];
    if (cached != null && !cached.isExpired) {
      _cacheHit = true;
    } else {
      _cache.remove(widget.productId);
      _startPayment();
    }
  }

  /// Elimina entradas expiradas del caché.
  void _cleanExpiredCache() {
    _cache.removeWhere((_, entry) => entry.isExpired);
  }

  /// Crea un [QrPaymentCubit] e inicia el flujo orden + QR + polling.
  void _startPayment() {
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

    unawaited(
      _cubit!.startQrPayment(
        merchantId: widget.merchantId,
        amount: widget.price,
        customerName: 'Cliente',
        phoneNumber: '',
        whereEat: 'dineIn',
        cartItems: cartItems,
        menuData: menuData,
      ),
    );
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _cubit?.close();
    super.dispose();
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

    // ── Cache hit: mostrar QR cacheado, sin cubit ──
    if (_cacheHit) {
      final cached = _cache[widget.productId]!;
      return ProductQrPanel(
        price: widget.price,
        qrBase64: cached.qrBase64,
        isPolling: true, // El polling está implícito mientras se espera el pago
      );
    }

    // ── Sin cubit (no debería ocurrir, fallback seguro) ──
    final cubit = _cubit;
    if (cubit == null) {
      return ProductQrPanel(
        price: widget.price,
        isLoading: true,
      );
    }

    // ── Cubit activo ──
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

    // ── QR listo: cachear ──
    if (state.status == QrPaymentStatus.qrReady &&
        state.qrBase64 != null &&
        state.orderId != null) {
      _cache[widget.productId] = _CachedQr(
        qrBase64: state.qrBase64!,
        orderId: state.orderId!,
        createdAt: DateTime.now(),
      );
    }

    // ── Pago exitoso ──
    if (state.status == QrPaymentStatus.success) {
      _onPaymentSuccess();
    }

    // ── Pago fallido o expirado: invalidar caché ──
    if (state.status == QrPaymentStatus.failed) {
      _cache.remove(widget.productId);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Manejo de éxito
  // ─────────────────────────────────────────────────────────────

  void _onPaymentSuccess() {
    if (_isSuccess) return; // Evitar doble ejecución

    _cache.remove(widget.productId);
    AudioService.playThanks();

    setState(() => _isSuccess = true);

    // Después de mostrar el éxito, reiniciar para permitir nueva compra
    _resetTimer?.cancel();
    _resetTimer = Timer(_successDisplayDuration, _resetForNewPurchase);
  }

  /// Cierra el cubit viejo, limpia caché y genera un QR fresco.
  void _resetForNewPurchase() {
    if (!mounted) return;

    _cache.remove(widget.productId);
    _cubit?.close();
    _cubit = null;
    _cacheHit = false;

    setState(() {
      _isSuccess = false;
    });

    _startPayment();
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
      isPolling: state.isPolling && state.status == QrPaymentStatus.qrReady,
      isSuccess: state.status == QrPaymentStatus.success,
      errorMessage:
          state.status == QrPaymentStatus.failed ? state.errorMessage : null,
    );
  }
}
