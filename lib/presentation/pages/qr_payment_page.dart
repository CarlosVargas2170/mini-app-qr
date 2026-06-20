import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/audio_service.dart';
import '../../core/ui/themes/app_colors.dart';
import '../../qr_payment_module/qr_payment_module.dart';

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
            customerName: widget.customerName,
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
              _showResultDialog('Pago exitoso', Icons.check_circle, Colors.green);
            } else if (state.status == QrPaymentStatus.failed) {
              _showResultDialog('Pago fallido', Icons.error_outline, AppColors.error);
            }
          },
          builder: (context, state) {
            return switch (state.status) {
              QrPaymentStatus.initial || QrPaymentStatus.loading => _buildLoading(),
              QrPaymentStatus.qrReady => _buildQr(state),
              QrPaymentStatus.success => _buildSuccess(),
              QrPaymentStatus.failed => _buildFailed(state),
              QrPaymentStatus.cancelled => _buildCancelled(),
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

  Widget _buildQr(QrPaymentState state) {
    final canCancel = _secondsLeft <= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = (constraints.maxHeight - 260).clamp(220.0, 480.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header con botón atrás
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textMuted),
                  ),
                  const Expanded(
                    child: Text(
                      'PAGO QR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),

              // Título
              const Text(
                'ESCANEA PARA PAGAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'El QR expira en 3 minutos',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.warning, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // QR
              Center(
                child: Container(
                  width: qrSize,
                  height: qrSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGlow,
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: _buildQrImage(state.qrBase64),
                ),
              ),
              const SizedBox(height: 24),

              // Indicador de polling
              if (state.isPolling) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Text(
                state.isPolling
                    ? 'Esperando confirmación de pago...'
                    : 'Consultando estado...',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Botón cancelar / countdown
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: canCancel
                    ? TextButton.icon(
                        key: const ValueKey('cancel_active'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.textMuted, size: 18),
                        label: const Text(
                          'Cambiar método de pago',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                        ),
                      )
                    : Padding(
                        key: const ValueKey('cancel_countdown'),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Podrás cancelar en $_secondsLeft s...',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQrImage(String? qrBase64) {
    if (qrBase64 == null || qrBase64.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.black45, strokeWidth: 3),
            SizedBox(height: 16),
            Text(
              'Generando QR...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (qrBase64.startsWith('http')) {
      return Image.network(
        qrBase64,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: CircularProgressIndicator(color: Colors.black45));
        },
        errorBuilder: (_, _, _) => _fallbackIcon(),
      );
    }

    try {
      final raw = qrBase64.contains(',') ? qrBase64.split(',').last : qrBase64;
      final bytes = base64Decode(raw);
      return Image.memory(bytes, fit: BoxFit.contain);
    } catch (_) {
      return _fallbackIcon();
    }
  }

  Widget _fallbackIcon() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_rounded, color: Colors.black54, size: 80),
          SizedBox(height: 8),
          Text(
            'QR no disponible',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return _buildResultScreen(
      icon: Icons.check_circle,
      color: Colors.green,
      title: 'PAGO EXITOSO',
      message: 'Tu pedido ha sido confirmado.',
    );
  }

  Widget _buildFailed(QrPaymentState state) {
    return _buildResultScreen(
      icon: Icons.error_outline,
      color: AppColors.error,
      title: 'PAGO FALLIDO',
      message: state.errorMessage ?? 'El pago fue rechazado o expiró.',
      showRetry: true,
    );
  }

  Widget _buildCancelled() {
    return _buildResultScreen(
      icon: Icons.cancel_outlined,
      color: AppColors.textMuted,
      title: 'CANCELADO',
      message: 'El pago fue cancelado.',
    );
  }

  Widget _buildResultScreen({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    bool showRetry = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 100),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 40),
            if (showRetry)
              ElevatedButton.icon(
                onPressed: () {
                  context.read<QrPaymentCubit>().retryPolling(widget.merchantId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('REINTENTAR'),
              ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'VOLVER AL INICIO',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResultDialog(String title, IconData icon, Color color) {
    // El dialog se maneja visualmente en el builder; esto evita doble render
  }
}
