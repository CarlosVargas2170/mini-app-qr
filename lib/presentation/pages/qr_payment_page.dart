import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../core/ui/themes/app_colors.dart';
import '../../presentation/bloc/qr_payment_cubit.dart';
import '../../presentation/bloc/qr_payment_state.dart';
import '../widgets/payment_result.dart';
import '../widgets/qr_payment_content.dart';

class QrPaymentPage extends StatefulWidget {
  final int merchantId;
  final double amount;
  final String customerName;
  final String phoneNumber;
  final String whereEat;
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic>? menuData;
  final String? paymentReferenceOverride;

  const QrPaymentPage({
    super.key,
    required this.merchantId,
    required this.amount,
    this.customerName = 'Cliente',
    this.phoneNumber = '',
    this.whereEat = 'dineIn',
    required this.cartItems,
    this.menuData,
    this.paymentReferenceOverride,
  });

  @override
  State<QrPaymentPage> createState() => _QrPaymentPageState();
}

class _QrPaymentPageState extends State<QrPaymentPage> {
  static const _cancelDelay = 10;
  int _secondsLeft = _cancelDelay;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QrPaymentCubit>().startQrPayment(
            merchantId: widget.merchantId,
            amount: widget.amount,
            customerName: 'Totem Mesero', // Hardcoded
            phoneNumber: widget.phoneNumber,
            whereEat: widget.whereEat,
            cartItems: widget.cartItems,
            menuData: widget.menuData,
            paymentReferenceOverride: widget.paymentReferenceOverride,
          );
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_secondsLeft <= 0) { timer.cancel(); return; }
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: BlocConsumer<QrPaymentCubit, QrPaymentState>(
          listener: (context, state) {
            if (state.status == QrPaymentStatus.success) {
              AudioService.playThanks();
            } else if (state.status == QrPaymentStatus.failed) {
              // El error se muestra visualmente en el builder
            }
          },
          builder: (context, state) {
            return switch (state.status) {
              QrPaymentStatus.initial || QrPaymentStatus.loading => _buildLoading(),
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
                  message: state.errorMessage ?? 'El pago fue rechazado o expiró.',
                  showRetry: true,
                  onRetry: () {
                    context.read<QrPaymentCubit>().retryPolling(widget.merchantId);
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
            'Generando código QR...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
