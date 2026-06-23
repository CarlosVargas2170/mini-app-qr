import 'package:flutter/material.dart';
import '../../core/ui/themes/app_colors.dart';

/// Widget que muestra el resultado de un pago (éxito, fallo o cancelado).
class PaymentResultWidget extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final bool showRetry;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  const PaymentResultWidget({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.showRetry = false,
    this.onRetry,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
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
                onPressed: onRetry,
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
              onPressed: onBack ?? () => Navigator.of(context).pop(),
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
}
