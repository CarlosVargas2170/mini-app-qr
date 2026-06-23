import 'package:flutter/material.dart';
import '../../core/ui/themes/app_colors.dart';
import '../../presentation/bloc/qr_payment_state.dart';
import 'qr_image_widget.dart';

/// Contenido principal de la pantalla de pago QR cuando el QR está listo.
class QrPaymentContent extends StatelessWidget {
  final QrPaymentState state;
  final int secondsLeft;
  final VoidCallback? onCancel;

  const QrPaymentContent({
    super.key,
    required this.state,
    required this.secondsLeft,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final canCancel = secondsLeft <= 0;

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
                  child: QrImageWidget(qrBase64: state.qrBase64),
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
                        onPressed: onCancel ?? () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: AppColors.textMuted, size: 18),
                        label: const Text(
                          'Volver al inicio',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                        ),
                      )
                    : Padding(
                        key: const ValueKey('cancel_countdown'),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Podrás cancelar en $secondsLeft s...',
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
}
