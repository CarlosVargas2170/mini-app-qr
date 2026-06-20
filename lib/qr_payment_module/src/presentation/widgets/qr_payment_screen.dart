import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../presentation/bloc/qr_payment_cubit.dart';
import '../../presentation/bloc/qr_payment_state.dart';
import 'qr_display_widget.dart';

/// Pantalla completa de pago QR lista para usar.
///
/// Muestra:
/// - Titulo y subtitulo
/// - QR generado (o loading)
/// - Mensaje de expiracion
/// - Boton de cancelar (despues de un delay opcional)
/// - Estados de exito / error
class QrPaymentScreen extends StatefulWidget {
  final int merchantId;
  final double amount;
  final String customerName;
  final String phoneNumber;
  final String whereEat;
  final List<Map<String, dynamic>> cartItems;
  final Map<String, dynamic>? menuData;
  final String? paymentReferenceOverride;

  final String title;
  final String subtitle;
  final String expiryMessage;
  final String cancelButtonText;
  final Duration cancelButtonDelay;
  final VoidCallback? onSuccess;
  final VoidCallback? onCancelled;
  final VoidCallback? onFailed;

  const QrPaymentScreen({
    super.key,
    required this.merchantId,
    required this.amount,
    required this.customerName,
    this.phoneNumber = '',
    this.whereEat = 'dineIn',
    required this.cartItems,
    this.menuData,
    this.paymentReferenceOverride,
    this.title = 'ESCANEA PARA PAGAR',
    this.subtitle = 'Usa tu app de pagos favorita',
    this.expiryMessage = 'El QR expira en 3 minutos',
    // this.cancelButtonText = 'Cambiar metodo de pago',
    this.cancelButtonText = 'Cancelar',
    this.cancelButtonDelay = const Duration(seconds: 10),
    this.onSuccess,
    this.onCancelled,
    this.onFailed,
  });

  @override
  State<QrPaymentScreen> createState() => _QrPaymentScreenState();
}

class _QrPaymentScreenState extends State<QrPaymentScreen> {
  bool _showCancel = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.cancelButtonDelay, () {
      if (mounted) setState(() => _showCancel = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QrPaymentCubit>().startQrPayment(
            merchantId: widget.merchantId,
            amount: widget.amount,
            customerName: widget.customerName,
            phoneNumber: widget.phoneNumber,
            whereEat: widget.whereEat,
            cartItems: widget.cartItems,
            menuData: widget.menuData,
            paymentReferenceOverride: widget.paymentReferenceOverride,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: BlocConsumer<QrPaymentCubit, QrPaymentState>(
            listener: (context, state) {
              if (state.status == QrPaymentStatus.success) {
                widget.onSuccess?.call();
              } else if (state.status == QrPaymentStatus.cancelled) {
                widget.onCancelled?.call();
              } else if (state.status == QrPaymentStatus.failed) {
                widget.onFailed?.call();
              }
            },
            builder: (context, state) {
              return switch (state.status) {
                QrPaymentStatus.initial || QrPaymentStatus.loading => _buildLoading(),
                QrPaymentStatus.qrReady => _buildQr(state),
                QrPaymentStatus.success => _buildSuccess(),
                QrPaymentStatus.failed => _buildError(state.errorMessage),
                QrPaymentStatus.cancelled => _buildCancelled(),
              };
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Preparando pago QR...'),
      ],
    );
  }

  Widget _buildQr(QrPaymentState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          QrDisplayWidget(
            qrBase64: state.qrBase64,
            size: (MediaQuery.of(context).size.height - 280).clamp(200.0, 400.0),
          ),
          const SizedBox(height: 24),
          Text(
            widget.expiryMessage,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange,
                ),
          ),
          const SizedBox(height: 32),
          if (_showCancel)
            OutlinedButton.icon(
              onPressed: () => context.read<QrPaymentCubit>().cancel(),
              icon: const Icon(Icons.arrow_back),
              label: Text(widget.cancelButtonText),
            ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 16),
        Text(
          'Pago exitoso',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }

  Widget _buildError(String? message) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        Text(
          message ?? 'Ocurrio un error',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            context.read<QrPaymentCubit>().retryPolling(widget.merchantId);
          },
          child: const Text('Reintentar'),
        ),
      ],
    );
  }

  Widget _buildCancelled() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.cancel_outlined, color: Colors.grey, size: 80),
        const SizedBox(height: 16),
        Text(
          'Pago cancelado',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ],
    );
  }
}
