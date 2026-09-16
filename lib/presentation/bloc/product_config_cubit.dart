import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/selected_topping.dart';
import '../../domain/entities/topping.dart';
import 'product_config_state.dart';

/// Gestiona la seleccion de toppings del modal de configuracion de un
/// producto, replicando las reglas de validacion min/max por grupo.
class ProductConfigCubit extends Cubit<ProductConfigState> {
  ProductConfigCubit(Product product)
      : super(ProductConfigState.initial(product));

  void setQuantity(int quantity) {
    if (quantity < 1) return;
    emit(state.copyWith(quantity: quantity));
  }

  /// Selecciona [subTopping] en un grupo `radio` (reemplaza la seleccion
  /// anterior de ese grupo).
  void selectRadioOption(Topping topping, SubTopping subTopping) {
    final updated = state.selectedToppings.map((selection) {
      if (selection.topping.id != topping.id) return selection;
      return SelectedTopping(
        topping: topping,
        selectedSubToppings: [subTopping],
      );
    }).toList();

    emit(_afterChange(state.copyWith(selectedToppings: updated), topping.id));
  }

  /// Marca/desmarca [subTopping] en un grupo `checkbox`. Si [selected] es
  /// `true` y el grupo ya alcanzo `maxLimit`, no hace nada (el maximo se
  /// previene en la UI, igual que el resto de la validacion de checkboxes).
  void toggleCheckboxOption(
      Topping topping, SubTopping subTopping, bool selected) {
    final current = state.selectedToppings.firstWhere(
      (s) => s.topping.id == topping.id,
      orElse: () =>
          SelectedTopping(topping: topping, selectedSubToppings: const []),
    );

    final subToppings = List<SubTopping>.from(current.selectedSubToppings);
    if (selected) {
      if (topping.maxLimit > 0 && subToppings.length >= topping.maxLimit) {
        return;
      }
      if (!subToppings.any((s) => s.id == subTopping.id)) {
        subToppings.add(subTopping);
      }
    } else {
      subToppings.removeWhere((s) => s.id == subTopping.id);
    }

    final updated = state.selectedToppings.map((selection) {
      if (selection.topping.id != topping.id) return selection;
      return SelectedTopping(
          topping: topping, selectedSubToppings: subToppings);
    }).toList();

    emit(_afterChange(state.copyWith(selectedToppings: updated), topping.id));
  }

  /// Fija la cantidad de [subTopping] dentro de un grupo `increment`.
  void setIncrementalQuantity(
      Topping topping, SubTopping subTopping, int quantity) {
    final extras = Map<int, Map<int, int>>.from(state.extraQuantities);
    final subQuantities = Map<int, int>.from(extras[topping.id] ?? const {});

    if (quantity > 0) {
      subQuantities[subTopping.id] = quantity;
    } else {
      subQuantities.remove(subTopping.id);
    }

    if (subQuantities.isEmpty) {
      extras.remove(topping.id);
    } else {
      extras[topping.id] = subQuantities;
    }

    emit(_afterChange(state.copyWith(extraQuantities: extras), topping.id));
  }

  /// Actualiza `resolvedToppingIds` tras un cambio: si el grupo afectado ya
  /// es valido, deja de marcarse en rojo aunque queden otros grupos
  /// pendientes.
  ProductConfigState _afterChange(ProductConfigState next, int toppingId) {
    if (!next.showValidationErrors) return next;

    final topping = next.product.toppingById(toppingId);
    if (topping == null) return next;

    final resolved = Set<int>.from(next.resolvedToppingIds);
    if (next.isGroupValid(topping)) {
      resolved.add(toppingId);
    } else {
      resolved.remove(toppingId);
    }
    return next.copyWith(resolvedToppingIds: resolved);
  }

  /// Intenta validar la configuracion actual. Devuelve `true` si es valida
  /// (el llamador puede agregar al carrito); si no, activa la exhibicion de
  /// errores por grupo y devuelve `false`.
  bool validateForAdd() {
    if (state.isValid) return true;
    emit(state
        .copyWith(showValidationErrors: true, resolvedToppingIds: const {}));
    return false;
  }
}
