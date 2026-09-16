import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config/app_settings.dart';
import '../../core/ui/themes/app_colors.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/selected_topping.dart';
import '../../domain/entities/topping.dart';
import '../bloc/product_config_cubit.dart';
import '../bloc/product_config_state.dart';
import 'product_quantity_selector.dart';

/// Callback invocado cuando el usuario confirma la configuracion del
/// producto y quiere agregarla al carrito.
typedef OnConfirmToppings = void Function({
  required List<SelectedTopping> selectedToppings,
  required Map<int, Map<int, int>> extraQuantities,
  required int quantity,
});

/// Boton flotante que abre una mini ventana anclada (no un sheet a pantalla
/// completa) para configurar los toppings de [product].
///
/// Usa el mismo mecanismo que `FloatingCart` (`LayerLink` +
/// `CompositedTransformFollower` + `OverlayEntry`) para que el popup quede
/// acotado a un tamano fijo cerca del boton, en vez de invadir la parte de
/// la pantalla que no es visible/tactil en el hardware del totem.
class ProductToppingsButton extends StatefulWidget {
  final Product product;
  final OnConfirmToppings onConfirm;
  final VoidCallback onInteraction;

  const ProductToppingsButton({
    super.key,
    required this.product,
    required this.onConfirm,
    required this.onInteraction,
  });

  @override
  State<ProductToppingsButton> createState() => _ProductToppingsButtonState();
}

class _ProductToppingsButtonState extends State<ProductToppingsButton> {
  bool _isOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  ProductConfigCubit? _cubit;

  @override
  void didUpdateWidget(covariant ProductToppingsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El carrusel cambio de producto mientras el popup estaba abierto: la
    // configuracion en curso ya no aplica.
    if (_isOpen && widget.product.id != oldWidget.product.id) {
      _closeOverlay();
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
      child: FloatingActionButton(
        heroTag: 'toppings-button',
        onPressed: _isOpen ? _closeOverlay : _openOverlay,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.accent,
        child: const Icon(Icons.tune),
      ),
    );
  }

  void _openOverlay() {
    if (_isOpen) return;

    widget.onInteraction();
    _isOpen = true;
    _cubit = ProductConfigCubit(widget.product);
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
                child: BlocProvider.value(
                  value: _cubit!,
                  child: _ToppingsPanel(
                    product: widget.product,
                    onConfirm: _handleConfirm,
                    onClose: _closeOverlay,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _handleConfirm({
    required List<SelectedTopping> selectedToppings,
    required Map<int, Map<int, int>> extraQuantities,
    required int quantity,
  }) {
    widget.onConfirm(
      selectedToppings: selectedToppings,
      extraQuantities: extraQuantities,
      quantity: quantity,
    );
    _closeOverlay();
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
    _cubit?.close();
    _cubit = null;
  }
}

class _ToppingsPanel extends StatelessWidget {
  final Product product;
  final OnConfirmToppings onConfirm;
  final VoidCallback onClose;

  const _ToppingsPanel({
    required this.product,
    required this.onConfirm,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxPanelHeight = (size.height * .55).clamp(320.0, 520.0).toDouble();

    return Listener(
      onPointerDown: (_) {}, // Absorbe el toque: no cierra el popup.
      child: Container(
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
        child: BlocBuilder<ProductConfigCubit, ProductConfigState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(product: product, onClose: onClose),
                const Divider(height: 1, color: AppColors.border),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final topping
                            in product.toppings ?? const <Topping>[])
                          _ToppingGroup(topping: topping, state: state),
                        const SizedBox(height: 8),
                        Center(
                          child: ProductQuantitySelector(
                            quantity: state.quantity,
                            maxQuantity: AppSettings().maxCartItemQuantity,
                            onIncrement: () => context
                                .read<ProductConfigCubit>()
                                .setQuantity(state.quantity + 1),
                            onDecrement: () => context
                                .read<ProductConfigCubit>()
                                .setQuantity(state.quantity - 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                _ConfirmBar(onConfirm: onConfirm),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Product product;
  final VoidCallback onClose;
  const _Header({required this.product, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${product.price} Bs',
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _ToppingGroup extends StatelessWidget {
  final Topping topping;
  final ProductConfigState state;

  const _ToppingGroup({required this.topping, required this.state});

  bool get _hasError =>
      state.showValidationErrors &&
      !state.resolvedToppingIds.contains(topping.id) &&
      !state.isGroupValid(topping);

  String get _instruction {
    final min = topping.minLimit;
    final max = topping.maxLimit;
    switch (topping.type) {
      case ToppingType.radio:
        return min > 0 ? 'Elige 1 opción' : 'Elige 1 opción (opcional)';
      case ToppingType.checkbox:
        if (min > 0 && max > 0) return 'Elige entre $min y $max opciones';
        if (min > 0) return 'Elige al menos $min';
        if (max > 0) return 'Elige hasta $max opciones';
        return 'Opcional';
      case ToppingType.increment:
        if (min > 0 && max > 0) return 'Agrega entre $min y $max';
        if (min > 0) return 'Agrega al menos $min';
        if (max > 0) return 'Agrega hasta $max';
        return 'Opcional';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topping.name,
                  style: TextStyle(
                    color: _hasError ? AppColors.error : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                _instruction,
                style: TextStyle(
                  color: _hasError ? AppColors.error : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (topping.type == ToppingType.radio)
            _RadioOptions(topping: topping, state: state),
          if (topping.type == ToppingType.checkbox)
            _CheckboxOptions(topping: topping, state: state),
          if (topping.type == ToppingType.increment)
            _IncrementOptions(topping: topping, state: state),
        ],
      ),
    );
  }
}

class _RadioOptions extends StatelessWidget {
  final Topping topping;
  final ProductConfigState state;
  const _RadioOptions({required this.topping, required this.state});

  @override
  Widget build(BuildContext context) {
    final selection = state.selectedToppings.firstWhere(
      (s) => s.topping.id == topping.id,
      orElse: () =>
          SelectedTopping(topping: topping, selectedSubToppings: const []),
    );
    final selectedId = selection.selectedSubToppings.isEmpty
        ? null
        : selection.selectedSubToppings.first.id;

    return RadioGroup<int>(
      groupValue: selectedId,
      onChanged: (value) {
        if (value == null) return;
        final sub = topping.subToppingById(value);
        if (sub != null) {
          context.read<ProductConfigCubit>().selectRadioOption(topping, sub);
        }
      },
      child: Column(
        children: topping.subToppings.map((sub) {
          return RadioListTile<int>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeColor: AppColors.accent,
            value: sub.id,
            title: Text(sub.name, style: const TextStyle(color: Colors.white)),
            subtitle: sub.price > 0
                ? Text('+${sub.price.toStringAsFixed(2)} Bs',
                    style: const TextStyle(color: AppColors.textSecondary))
                : null,
          );
        }).toList(),
      ),
    );
  }
}

class _CheckboxOptions extends StatelessWidget {
  final Topping topping;
  final ProductConfigState state;
  const _CheckboxOptions({required this.topping, required this.state});

  @override
  Widget build(BuildContext context) {
    final selection = state.selectedToppings.firstWhere(
      (s) => s.topping.id == topping.id,
      orElse: () =>
          SelectedTopping(topping: topping, selectedSubToppings: const []),
    );
    final selectedIds = selection.selectedSubToppings.map((s) => s.id).toSet();
    final atMax =
        topping.maxLimit > 0 && selectedIds.length >= topping.maxLimit;

    return Column(
      children: topping.subToppings.map((sub) {
        final isSelected = selectedIds.contains(sub.id);
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeColor: AppColors.accent,
          value: isSelected,
          onChanged: (!isSelected && atMax)
              ? null
              : (value) => context
                  .read<ProductConfigCubit>()
                  .toggleCheckboxOption(topping, sub, value ?? false),
          title: Text(sub.name, style: const TextStyle(color: Colors.white)),
          subtitle: sub.price > 0
              ? Text('+${sub.price.toStringAsFixed(2)} Bs',
                  style: const TextStyle(color: AppColors.textSecondary))
              : null,
        );
      }).toList(),
    );
  }
}

class _IncrementOptions extends StatelessWidget {
  final Topping topping;
  final ProductConfigState state;
  const _IncrementOptions({required this.topping, required this.state});

  @override
  Widget build(BuildContext context) {
    final subQuantities = state.extraQuantities[topping.id] ?? const {};
    final total = state.extraQuantityFor(topping.id);
    final atMax = topping.maxLimit > 0 && total >= topping.maxLimit;

    return Column(
      children: topping.subToppings.map((sub) {
        final qty = subQuantities[sub.id] ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child:
                    Text(sub.name, style: const TextStyle(color: Colors.white)),
              ),
              if (sub.price > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('+${sub.price.toStringAsFixed(2)} Bs',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
              IconButton(
                onPressed: qty > 0
                    ? () => context
                        .read<ProductConfigCubit>()
                        .setIncrementalQuantity(topping, sub, qty - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline,
                    color: Colors.white),
              ),
              SizedBox(
                width: 24,
                child: Text('$qty',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
              ),
              IconButton(
                onPressed: atMax
                    ? null
                    : () => context
                        .read<ProductConfigCubit>()
                        .setIncrementalQuantity(topping, sub, qty + 1),
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  final OnConfirmToppings onConfirm;
  const _ConfirmBar({required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductConfigCubit, ProductConfigState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                final cubit = context.read<ProductConfigCubit>();
                if (!cubit.validateForAdd()) return;
                onConfirm(
                  selectedToppings: state.selectedToppings
                      .where((s) => s.selectedSubToppings.isNotEmpty)
                      .toList(),
                  extraQuantities: state.extraQuantities,
                  quantity: state.quantity,
                );
              },
              child: Text(
                'AGREGAR · ${state.totalPrice.toStringAsFixed(2)} Bs',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        );
      },
    );
  }
}
