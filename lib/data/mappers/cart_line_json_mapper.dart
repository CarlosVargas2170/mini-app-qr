import '../../domain/entities/product.dart';
import '../../domain/entities/selected_topping.dart';
import '../../domain/entities/topping.dart';

/// Serializacion JSON de la configuracion de toppings de una linea de
/// carrito. Se usa en el snapshot que arma `home_page.dart` para el pago
/// (`cartItems`), y lo consumen `QrPaymentCubit` (revalidacion de precio) y
/// `PlaceOrderRequestDto` (payload de `/orders/create-pending`).

/// Convierte los toppings elegidos (checkbox/radio) a JSON. Solo incluye
/// grupos con al menos una opcion seleccionada.
List<Map<String, dynamic>> toppingsToJson(
    List<SelectedTopping> selectedToppings) {
  return selectedToppings
      .where((selection) => selection.selectedSubToppings.isNotEmpty)
      .map((selection) => {
            'toppingId': selection.topping.id,
            'toppingName': selection.topping.name,
            'type': selection.topping.type.name,
            'minLimit': selection.topping.minLimit,
            'maxLimit': selection.topping.maxLimit,
            'subToppings': selection.selectedSubToppings
                .map((sub) =>
                    {'id': sub.id, 'name': sub.name, 'price': sub.price})
                .toList(),
          })
      .toList();
}

/// Convierte `extraQuantities` (`toppingId -> subToppingId -> cantidad`) a
/// un mapa JSON-serializable con claves de texto.
Map<String, dynamic> extraQuantitiesToJson(
    Map<int, Map<int, int>> extraQuantities) {
  final result = <String, dynamic>{};
  extraQuantities.forEach((toppingId, subQuantities) {
    result[toppingId.toString()] =
        subQuantities.map((subId, qty) => MapEntry(subId.toString(), qty));
  });
  return result;
}

/// Inverso de [extraQuantitiesToJson]. Tolera `null`/formatos invalidos
/// devolviendo un mapa vacio.
Map<int, Map<int, int>> extraQuantitiesFromJson(dynamic raw) {
  if (raw is! Map) return const {};
  final result = <int, Map<int, int>>{};
  raw.forEach((toppingIdKey, subQuantities) {
    final toppingId = int.tryParse(toppingIdKey.toString());
    if (toppingId == null || subQuantities is! Map) return;
    final subMap = <int, int>{};
    subQuantities.forEach((subIdKey, qty) {
      final subId = int.tryParse(subIdKey.toString());
      final quantity = (qty as num?)?.toInt();
      if (subId != null && quantity != null) subMap[subId] = quantity;
    });
    if (subMap.isNotEmpty) result[toppingId] = subMap;
  });
  return result;
}

/// Resultado de resolver los toppings serializados de un item de pago
/// contra el catalogo fresco: si algun grupo o sub-topping seleccionado ya
/// no existe, [isValid] es `false` y no debe usarse [selectedToppings].
class ResolvedSelectedToppings {
  final List<SelectedTopping> selectedToppings;
  final bool isValid;

  const ResolvedSelectedToppings(this.selectedToppings, this.isValid);
}

/// Reconstruye [SelectedTopping] a partir del JSON guardado en el item de
/// pago (`toppingsToJson`), usando los grupos/precios frescos de
/// [freshProduct] en vez de los capturados al momento de la seleccion.
///
/// Se usa antes de cobrar, para no confiar en un precio de topping que pudo
/// haber cambiado desde que el cliente armo su pedido.
ResolvedSelectedToppings resolveSelectedToppingsAgainstProduct(
  dynamic rawToppings,
  Product freshProduct,
) {
  if (rawToppings is! List) return const ResolvedSelectedToppings([], true);

  final resolved = <SelectedTopping>[];
  for (final entry in rawToppings) {
    if (entry is! Map) return const ResolvedSelectedToppings([], false);
    final toppingId = (entry['toppingId'] as num?)?.toInt();
    final freshTopping =
        toppingId == null ? null : freshProduct.toppingById(toppingId);
    if (freshTopping == null) return const ResolvedSelectedToppings([], false);

    final rawSubToppings = entry['subToppings'];
    if (rawSubToppings is! List || rawSubToppings.isEmpty) {
      return const ResolvedSelectedToppings([], false);
    }

    final freshSubToppings = <SubTopping>[];
    for (final rawSub in rawSubToppings) {
      final subId = (rawSub is Map) ? (rawSub['id'] as num?)?.toInt() : null;
      final freshSub =
          subId == null ? null : freshTopping.subToppingById(subId);
      if (freshSub == null) return const ResolvedSelectedToppings([], false);
      freshSubToppings.add(freshSub);
    }

    resolved.add(SelectedTopping(
      topping: freshTopping,
      selectedSubToppings: freshSubToppings,
    ));
  }

  return ResolvedSelectedToppings(resolved, true);
}

/// Igual que [resolveSelectedToppingsAgainstProduct] pero para
/// `extraQuantities`: valida que cada grupo/sub-topping siga existiendo en
/// [freshProduct] antes de usarlo para calcular precio.
class ResolvedExtraQuantities {
  final Map<int, Map<int, int>> extraQuantities;
  final bool isValid;

  const ResolvedExtraQuantities(this.extraQuantities, this.isValid);
}

ResolvedExtraQuantities resolveExtraQuantitiesAgainstProduct(
  dynamic rawExtraQuantities,
  Product freshProduct,
) {
  final parsed = extraQuantitiesFromJson(rawExtraQuantities);
  if (parsed.isEmpty) return const ResolvedExtraQuantities({}, true);

  for (final entry in parsed.entries) {
    final freshTopping = freshProduct.toppingById(entry.key);
    if (freshTopping == null) {
      return const ResolvedExtraQuantities({}, false);
    }
    for (final subToppingId in entry.value.keys) {
      if (freshTopping.subToppingById(subToppingId) == null) {
        return const ResolvedExtraQuantities({}, false);
      }
    }
  }

  return ResolvedExtraQuantities(parsed, true);
}
