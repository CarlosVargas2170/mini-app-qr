import 'package:flutter/material.dart';

import '../../core/ui/themes/app_colors.dart';
import '../../domain/entities/cart_item.dart';

class FloatingCart extends StatefulWidget {
  final List<CartItem> lines;
  final int totalItems;
  final double totalAmount;
  final int maxItemQuantity;
  final ValueChanged<String> onIncrementLine;
  final ValueChanged<String> onDecrementLine;
  final ValueChanged<String> onRemoveLine;
  final VoidCallback onClear;
  final VoidCallback onInteraction;

  const FloatingCart({
    super.key,
    required this.lines,
    required this.totalItems,
    required this.totalAmount,
    required this.maxItemQuantity,
    required this.onIncrementLine,
    required this.onDecrementLine,
    required this.onRemoveLine,
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
    if (!_isOpen) return;

    // didUpdateWidget se ejecuta mientras Flutter esta reconstruyendo la Home.
    // Marcar el Overlay como sucio en ese instante puede provocar
    // "setState/markNeedsBuild called during build". Se actualiza al finalizar
    // el frame para mantener sincronizados el panel y el boton flotante.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isOpen) return;
      if (widget.totalItems == 0) {
        _removeOverlay();
        setState(() {});
        return;
      }
      _overlayEntry?.markNeedsBuild();
    });
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
                    child: Text('Tu carrito',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
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
                itemCount: widget.lines.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: AppColors.border),
                itemBuilder: (context, index) {
                  final line = widget.lines[index];
                  return _CartLineTile(
                    line: line,
                    maxQuantity: widget.maxItemQuantity,
                    onIncrement: () => widget.onIncrementLine(line.id),
                    onDecrement: () => _decrementLine(line),
                    onRemove: () => _removeLine(line),
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
                  Text('${widget.totalItems} unidades',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  Text('${widget.totalAmount.toStringAsFixed(2)} Bs',
                      style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _decrementLine(CartItem line) {
    final shouldClose = line.quantity == 1 && widget.totalItems == 1;
    widget.onDecrementLine(line.id);

    // Actualizar primero el carrito evita desmontar el Overlay mientras el
    // IconButton todavia esta procesando el gesto de la ultima unidad.
    if (shouldClose) {
      _closeOverlay();
    }
  }

  void _requestClear() {
    _closeOverlay();
    widget.onClear();
  }

  void _removeLine(CartItem line) {
    final shouldClose = widget.totalItems == line.quantity;
    widget.onRemoveLine(line.id);

    if (shouldClose) {
      _closeOverlay();
    }
  }
}

class _CartLineTile extends StatelessWidget {
  final CartItem line;
  final int maxQuantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  const _CartLineTile({
    required this.line,
    required this.maxQuantity,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  /// Resumen legible de la configuracion elegida (subtoppings y extras),
  /// o cadena vacia si la linea no tiene toppings.
  String _configurationSummary() {
    final parts = <String>[];
    for (final selection in line.selectedToppings) {
      for (final subTopping in selection.selectedSubToppings) {
        parts.add(subTopping.name);
      }
    }
    line.extraQuantities.forEach((toppingId, subQuantities) {
      final topping = line.product.toppingById(toppingId);
      subQuantities.forEach((subToppingId, qty) {
        final subTopping = topping?.subToppingById(subToppingId);
        if (subTopping != null) parts.add('${subTopping.name} x$qty');
      });
    });
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final summary = _configurationSummary();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (summary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '${line.unitPrice.toStringAsFixed(2)} Bs c/u · Cantidad: ${line.quantity}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                'Subtotal: ${line.totalPrice.toStringAsFixed(2)} Bs',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: ValueKey('cart-decrement-${line.id}'),
          onPressed: onDecrement,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('${line.quantity}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        IconButton(
          onPressed: line.quantity < maxQuantity ? onIncrement : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
        IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: AppColors.error)),
      ],
    );
  }
}
