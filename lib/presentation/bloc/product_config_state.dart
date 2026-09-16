import 'package:equatable/equatable.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/selected_topping.dart';
import '../../domain/entities/topping.dart';

/// Estado del modal de configuracion de toppings de un producto.
///
/// Mantiene una entrada de [SelectedTopping] por cada grupo `checkbox`/
/// `radio` del producto (aunque no tenga nada elegido todavia, para poder
/// pintar el grupo completo), y las cantidades de los grupos `increment`
/// por separado en [extraQuantities].
class ProductConfigState extends Equatable {
  final Product product;
  final List<SelectedTopping> selectedToppings;
  final Map<int, Map<int, int>> extraQuantities;
  final int quantity;

  /// Solo se muestran errores despues de un intento fallido de confirmar.
  final bool showValidationErrors;

  /// Grupos que ya se corrigieron tras el ultimo intento fallido, para no
  /// seguir marcandolos en rojo mientras el usuario corrige otros.
  final Set<int> resolvedToppingIds;

  const ProductConfigState({
    required this.product,
    required this.selectedToppings,
    required this.extraQuantities,
    required this.quantity,
    this.showValidationErrors = false,
    this.resolvedToppingIds = const {},
  });

  factory ProductConfigState.initial(Product product) {
    final selectableGroups = (product.toppings ?? const [])
        .where((topping) => topping.type != ToppingType.increment)
        .map((topping) =>
            SelectedTopping(topping: topping, selectedSubToppings: const []))
        .toList();

    return ProductConfigState(
      product: product,
      selectedToppings: selectableGroups,
      extraQuantities: const {},
      quantity: 1,
    );
  }

  double get unitPrice => CartItem.unitPriceFor(
        product: product,
        selectedToppings: selectedToppings,
        extraQuantities: extraQuantities,
      );

  double get totalPrice => unitPrice * quantity;

  /// Cantidad total elegida en un grupo `increment`.
  int extraQuantityFor(int toppingId) {
    final subQuantities = extraQuantities[toppingId];
    if (subQuantities == null) return 0;
    return subQuantities.values.fold(0, (a, b) => a + b);
  }

  bool isGroupValid(Topping topping) {
    if (topping.type == ToppingType.increment) {
      final total = extraQuantityFor(topping.id);
      if (topping.minLimit > 0 && total < topping.minLimit) return false;
      if (topping.maxLimit > 0 && total > topping.maxLimit) return false;
      return true;
    }

    final selection = selectedToppings.firstWhere(
      (s) => s.topping.id == topping.id,
      orElse: () =>
          SelectedTopping(topping: topping, selectedSubToppings: const []),
    );

    if (topping.type == ToppingType.radio) {
      return topping.minLimit == 0 || selection.selectedSubToppings.isNotEmpty;
    }

    // checkbox: el maximo se previene en la UI: aqui solo se exige el minimo.
    return selection.selectedSubToppings.length >= topping.minLimit;
  }

  bool get isValid {
    final groups = product.toppings ?? const [];
    return groups.every(isGroupValid);
  }

  ProductConfigState copyWith({
    List<SelectedTopping>? selectedToppings,
    Map<int, Map<int, int>>? extraQuantities,
    int? quantity,
    bool? showValidationErrors,
    Set<int>? resolvedToppingIds,
  }) {
    return ProductConfigState(
      product: product,
      selectedToppings: selectedToppings ?? this.selectedToppings,
      extraQuantities: extraQuantities ?? this.extraQuantities,
      quantity: quantity ?? this.quantity,
      showValidationErrors: showValidationErrors ?? this.showValidationErrors,
      resolvedToppingIds: resolvedToppingIds ?? this.resolvedToppingIds,
    );
  }

  @override
  List<Object?> get props => [
        product,
        selectedToppings,
        extraQuantities,
        quantity,
        showValidationErrors,
        resolvedToppingIds,
      ];
}
