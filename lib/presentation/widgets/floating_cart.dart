import 'package:flutter/material.dart';

import '../../core/ui/themes/app_colors.dart';
import '../../domain/entities/product.dart';

class FloatingCart extends StatefulWidget {
  final List<Product> products;
  final int Function(Product product) quantityFor;
  final int totalItems;
  final double totalAmount;
  final int maxItemQuantity;
  final ValueChanged<Product> onIncrement;
  final ValueChanged<Product> onDecrement;
  final ValueChanged<Product> onRemove;
  final VoidCallback onClear;
  final VoidCallback onInteraction;

  const FloatingCart({
    super.key,
    required this.products,
    required this.quantityFor,
    required this.totalItems,
    required this.totalAmount,
    required this.maxItemQuantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onClear,
    required this.onInteraction,
  });

  @override
  State<FloatingCart> createState() => _FloatingCartState();
}

class _FloatingCartState extends State<FloatingCart> {
  bool _isOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void didUpdateWidget(covariant FloatingCart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen && widget.totalItems == 0) {
      _removeOverlay();
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildButton(),
      ),
    );
  }

  void _openOverlay() {
    if (_isOpen || widget.totalItems == 0) return;

    widget.onInteraction();
    _isOpen = true;
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeOverlay,
                child: const ColoredBox(color: Color(0x99000000)),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.bottomRight,
              child: SafeArea(
                minimum: const EdgeInsets.all(20),
                child: _buildPanel(overlayContext),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _closeOverlay() {
    if (!_isOpen) return;
    widget.onInteraction();
    _removeOverlay();
    if (mounted) setState(() {});
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  Widget _buildButton() {
    return Badge(
      key: const ValueKey('cart-button'),
      isLabelVisible: widget.totalItems > 0,
      label: Text('${widget.totalItems}'),
      child: FloatingActionButton.large(
        heroTag: 'floating-cart',
        onPressed: widget.totalItems == 0 ? null : _openOverlay,
        backgroundColor:
            widget.totalItems == 0 ? AppColors.surface : AppColors.accent,
        foregroundColor: AppColors.background,
        child: const Icon(Icons.shopping_cart, size: 32),
      ),
    );
  }

  Widget _buildPanel(BuildContext overlayContext) {
    final size = MediaQuery.sizeOf(overlayContext);
    final maxPanelHeight = (size.height * .55).clamp(320.0, 520.0).toDouble();
    return Listener(
      onPointerDown: (_) => widget.onInteraction(),
      child: Container(
        key: const ValueKey('cart-panel'),
        width: size.width < 520 ? size.width - 40 : 420,
        constraints: BoxConstraints(maxHeight: maxPanelHeight),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: AppColors.accent),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Tu carrito', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: _requestClear,
                  child: const Text('VACIAR'),
                ),
                IconButton(
                  onPressed: _closeOverlay,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(12),
              itemCount: widget.products.length,
              separatorBuilder: (_, __) => const Divider(color: AppColors.border),
              itemBuilder: (context, index) {
                final product = widget.products[index];
                return _CartItem(
                  product: product,
                  quantity: widget.quantityFor(product),
                  maxQuantity: widget.maxItemQuantity,
                  onIncrement: () => widget.onIncrement(product),
                  onDecrement: () => _decrementProduct(product),
                  onRemove: () => _removeProduct(product),
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.totalItems} unidades', style: const TextStyle(color: AppColors.textSecondary)),
                Text('${widget.totalAmount.toStringAsFixed(2)} Bs', style: const TextStyle(color: AppColors.warning, fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  void _decrementProduct(Product product) {
    final quantity = widget.quantityFor(product);
    if (quantity <= 0) return;
    if (quantity == 1 && widget.totalItems == 1) {
      _closeOverlay();
    }
    widget.onDecrement(product);
  }

  void _requestClear() {
    _closeOverlay();
    widget.onClear();
  }

  void _removeProduct(Product product) {
    if (widget.quantityFor(product) <= 0) return;
    if (widget.totalItems == widget.quantityFor(product)) {
      _closeOverlay();
    }
    widget.onRemove(product);
  }
}

class _CartItem extends StatelessWidget {
  final Product product;
  final int quantity;
  final int maxQuantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartItem({required this.product, required this.quantity, required this.maxQuantity, required this.onIncrement, required this.onDecrement, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${product.price.toStringAsFixed(2)} Bs c/u · Cantidad: $quantity',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'Subtotal: ${(product.price * quantity).toStringAsFixed(2)} Bs',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        IconButton(onPressed: onDecrement, icon: const Icon(Icons.remove_circle_outline)),
        Text('$quantity', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: quantity < maxQuantity ? onIncrement : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
        IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline, color: AppColors.error)),
      ],
    );
  }
}
