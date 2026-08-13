import 'package:flutter/material.dart';

import '../../core/ui/themes/app_colors.dart';

class ProductQuantitySelector extends StatelessWidget {
  final int quantity;
  final int maxQuantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const ProductQuantitySelector({
    super.key,
    required this.quantity,
    required this.maxQuantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _QuantityButton(
          icon: Icons.remove,
          onPressed: quantity > 0 ? onDecrement : null,
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 68),
          alignment: Alignment.center,
          child: Text(
            '$quantity',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _QuantityButton(
          icon: Icons.add,
          onPressed: quantity < maxQuantity ? onIncrement : null,
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;

  const _QuantityButton({required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      onPressed: onPressed,
      icon: Icon(icon, size: 28),
      style: IconButton.styleFrom(
        backgroundColor:
            onPressed == null ? AppColors.border : AppColors.accent,
        foregroundColor: AppColors.background,
        disabledForegroundColor: AppColors.textMuted,
        minimumSize: const Size(52, 52),
      ),
    );
  }
}
