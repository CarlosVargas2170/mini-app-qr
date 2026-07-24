import 'package:flutter/material.dart';
import '../../core/ui/themes/app_colors.dart';
import 'qr_image_widget.dart';

/// Panel que muestra el precio del producto, el QR de pago y un mensaje para escanear.
///
/// Soporta múltiples estados visuales:
/// - [isLoading]: spinner "Generando QR..."
/// - [isSuccess]: overlay verde de pago exitoso
/// - [errorMessage]: icono de error + mensaje
/// - [isPolling]: barra de progreso + "Esperando confirmación..."
/// - [qrBase64]: QR real generado por el backend
/// - fallback (ninguno de los anteriores): imagen estática de ejemplo
class ProductQrPanel extends StatelessWidget {
  final double price;
  final String? qrBase64;
  final bool isLoading;
  final bool isPolling;
  final bool isSuccess;
  final String? errorMessage;

  const ProductQrPanel({
    super.key,
    required this.price,
    this.qrBase64,
    this.isLoading = false,
    this.isPolling = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Precio ──
            Text(
              '${price.toStringAsFixed(2)} Bs',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.warning,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // ── QR / Estado ──
            Expanded(
              child: Center(child: _buildQrContent()),
            ),

            // ── Indicador de polling ──
            if (isPolling &&
                !isLoading &&
                !isSuccess &&
                errorMessage == null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Esperando confirmación...',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 4),
            ] else ...[
              const SizedBox(height: 8),
            ],

            // ── Mensaje inferior ──
            if (isSuccess)
              const Text(
                '¡Gracias por tu compra!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const Text(
                'Escanea el QR para pagar',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Construye el contenido del área central según el estado actual.
  Widget _buildQrContent() {
    // ── Éxito ──
    if (isSuccess) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 64),
          SizedBox(height: 12),
          Text(
            '¡PAGO EXITOSO!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.green,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Tu pedido ha sido confirmado.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      );
    }

    // ── Cargando ──
    if (isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
          SizedBox(height: 16),
          Text(
            'Generando QR...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      );
    }

    // ── Error ──
    if (errorMessage != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 48),
          const SizedBox(height: 8),
          Text(
            errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 13,
            ),
          ),
        ],
      );
    }

    // ── QR real ──
    if (qrBase64 != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentGlow,
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: QrImageWidget(qrBase64: qrBase64),
        ),
      );
    }

    // ── Fallback: imagen de ejemplo ──
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * 0.50;
        return Image.asset(
          'assets/images/qr_example.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    color: AppColors.textSecondary, size: 64),
                const SizedBox(height: 8),
                const Text(
                  'QR no disponible',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
