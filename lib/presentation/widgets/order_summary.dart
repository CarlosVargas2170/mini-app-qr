import 'package:flutter/material.dart';
import '../../core/ui/themes/app_colors.dart';
import '../../domain/entities/product.dart';

class OrderSummary extends StatelessWidget {
  final Product product;
  const OrderSummary({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final price = product.price;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RESUMEN DEL PEDIDO',
              style: TextStyle(
                color: AppColors.textCaption,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _RowLabel(label: 'Producto', value: product.name),
            const SizedBox(height: 8),
            const _RowLabel(label: 'Cantidad', value: '1'),
            const SizedBox(height: 8),
            _RowLabel(label: 'Precio unitario', value: '$price Bs'),
            const Divider(color: AppColors.border, height: 24),
            _RowLabel(
              label: 'TOTAL',
              value: '$price Bs',
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;
  const _RowLabel({required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? AppColors.accent : AppColors.textPrimary,
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
