import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/app_settings.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/payment_counter.dart';
import '../../core/services/payment_polling_status.dart';
import '../../core/ui/themes/app_colors.dart';
import '../../presentation/bloc/qr_payment_cubit.dart';
import '../../presentation/bloc/qr_payment_state.dart';
import '../widgets/payment_result.dart';
import '../widgets/qr_payment_content.dart';

class QrPaymentPage extends StatefulWidget {
  final int merchantId;
  final int productId;
  final double amount;
  final String? customerName;
  final String phoneNumber;
  final String whereEat;
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic>? menuData;
  final String? nit;
  final String? businessName;
  final String? paymentReferenceOverride;
  final VoidCallback? onSuccess;

  const QrPaymentPage({
    super.key,
    required this.merchantId,
    required this.productId,
    required this.amount,
    this.customerName,
    this.phoneNumber = '',
    this.whereEat = 'dineIn',
    required this.cartItems,
    this.menuData,
    this.nit,
    this.businessName,
    this.paymentReferenceOverride,
    this.onSuccess,
  });

  @override
  State<QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<QrPaymentPage> {
  static const _cancelDelay = 10;
  static const _successReturnDelay = Duration(seconds: 5);
  int _secondsLeft = _cancelDelay;
  Timer? _countdownTimer;
  Timer? _successReturnTimer;

  /// Bloqueo local: una vez éxito, la UI no vuelve a cancelado/fallido.
  bool _paymentSucceeded = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QrPaymentCubit>().startQrPayment(
            merchantId: widget.merchantId,
            productId: widget.productId,
            amount: widget.amount,
            customerName: widget.customerName ?? AppSettings.customerName,
            phoneNumber: widget.phoneNumber,
            whereEat: widget.whereEat,
            cartItems: widget.cartItems,
            menuData: widget.menuData,
            nit: widget.nit,
            businessName: widget.businessName,
            paymentReferenceOverride: widget.paymentReferenceOverride,
          );
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _successReturnTimer?.cancel();
    PaymentPollingStatus().setIdle();
    // Solo detener polling: NO emitir cancelled (evita flash de UI cancelada
    // después del éxito al hacer pop / dispose).
    try {
      context.read<QrPaymentCubit>().stopPollingOnly();
    } catch (_) {
      // Cubit ya cerrado o no disponible en el árbol.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<QrPaymentCubit, QrPaymentState>(
          listener: (context, state) {
            _publishToRemoteControl(state);

            if (state.status == QrPaymentStatus.success) {
              if (_paymentSucceeded) return;
              _paymentSucceeded = true;
              AudioService.playThanks();
              PaymentCounter().increment(
                amount: state.amount ?? widget.amount,
                productId: _productId ?? 0,
                productName: _productName,
                merchantId: widget.merchantId,
                cartItems: widget.cartItems,
              );
              // Volver al GIF automaticamente despues de unos segundos
              _successReturnTimer?.cancel();
              _successReturnTimer = Timer(_successReturnDelay, () {
                if (!mounted) return;
                widget.onSuccess?.call();
              });
            }
          },
          builder: (context, state) {
            // Prioridad absoluta al éxito: no dejar que cancelled pise la UI.
            if (_paymentSucceeded || state.status == QrPaymentStatus.success) {
              return PaymentResultWidget(
                icon: Icons.check_circle,
                color: Colors.green,
                title: 'PAGO EXITOSO',
                message: 'Tu pedido ha sido confirmado.',
                onBack: () => Navigator.of(context).pop(),
              );
            }

            return switch (state.status) {
              QrPaymentStatus.initial ||
              QrPaymentStatus.loading =>
                _buildLoading(),
              QrPaymentStatus.qrReady => QrPaymentContent(
                  state: state,
                  secondsLeft: _secondsLeft,
                ),
              QrPaymentStatus.success => PaymentResultWidget(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  title: 'PAGO EXITOSO',
                  message: 'Tu pedido ha sido confirmado.',
                  onBack: () => Navigator.of(context).pop(),
                ),
              QrPaymentStatus.failed => PaymentResultWidget(
                  icon: Icons.error_outline,
                  color: AppColors.error,
                  title: 'PAGO FALLIDO',
                  message:
                      state.errorMessage ?? 'El pago fue rechazado o expiró.',
                  showRetry: true,
                  onRetry: () {
                    context
                        .read<QrPaymentCubit>()
                        .retryPolling(widget.merchantId);
                  },
                  onBack: () => Navigator.of(context).pop(),
                ),
              QrPaymentStatus.cancelled => PaymentResultWidget(
                  icon: Icons.cancel_outlined,
                  color: AppColors.textMuted,
                  title: 'CANCELADO',
                  message: 'El pago fue cancelado.',
                  onBack: () => Navigator.of(context).pop(),
                ),
            };
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
          SizedBox(height: 24),
          Text(
            'Verificando pedido y generando QR...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Remote-control: publica estado al singleton global
  // ─────────────────────────────────────────────────────────────
  /// Nombre resumido de la compra para el estado remoto.
  String get _productName {
    if (widget.cartItems.isEmpty) return '';
    if (widget.cartItems.length == 1) {
      return (widget.cartItems.first['name'] as String?) ?? '';
    }
    return 'Pedido (${widget.cartItems.length} productos)';
  }

  /// ID del producto desde menuData (primer producto de la primera categoria).
  int? get _productId {
    final menuData = widget.menuData;
    if (menuData == null) return null;
    final categories = menuData['categories'] as List?;
    if (categories == null || categories.isEmpty) return null;
    final firstCategory = categories.first as Map?;
    if (firstCategory == null) return null;
    final products = firstCategory['products'] as List?;
    if (products == null || products.isEmpty) return null;
    final firstProduct = products.first as Map?;
    return firstProduct?['id'] as int?;
  }

  /// Sincroniza el estado del cubit con [PaymentPollingStatus]
  /// para que el remote-control refleje el progreso del pago.
  void _publishToRemoteControl(QrPaymentState state) {
    final pub = PaymentPollingStatus();

    switch (state.status) {
      case QrPaymentStatus.initial:
      case QrPaymentStatus.loading:
        pub.setWaiting(
          productId: _productId ?? 0,
          merchantId: widget.merchantId,
          orderId: state.orderId,
          amount: state.amount ?? widget.amount,
          productName: _productName,
        );
      case QrPaymentStatus.qrReady:
        if (state.isPolling) {
          pub.setPolling(
            productId: _productId ?? 0,
            merchantId: widget.merchantId,
            orderId: state.orderId!,
            amount: state.amount ?? widget.amount,
            productName: _productName,
          );
        } else {
          pub.setWaiting(
            productId: _productId ?? 0,
            merchantId: widget.merchantId,
            orderId: state.orderId,
            amount: state.amount ?? widget.amount,
            productName: _productName,
          );
        }
      case QrPaymentStatus.success:
        pub.setSuccess(
          productId: _productId,
          merchantId: widget.merchantId,
          orderId: state.orderId,
          amount: state.amount ?? widget.amount,
          productName: _productName,
        );
      case QrPaymentStatus.failed:
        pub.setFailed(
          productId: _productId,
          merchantId: widget.merchantId,
          orderId: state.orderId,
        );
      case QrPaymentStatus.cancelled:
        pub.setIdle();
    }
  }
}
