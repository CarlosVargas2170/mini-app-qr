import 'topping.dart';

/// Seleccion del usuario para un [Topping] concreto dentro de una linea de
/// carrito.
///
/// Para grupos `checkbox`/`radio`, [selectedSubToppings] contiene las
/// opciones elegidas y [quantity] no se usa. Para grupos `increment`, las
/// cantidades por sub-topping se llevan aparte en `CartItem.extraQuantities`
/// (misma separacion que usa el resto del negocio para este tipo de grupo).
class SelectedTopping {
  final Topping topping;
  final List<SubTopping> selectedSubToppings;

  const SelectedTopping({
    required this.topping,
    required this.selectedSubToppings,
  });

  /// Firma estable de la seleccion (ids ordenados), usada para comparar si
  /// dos lineas de carrito tienen exactamente la misma configuracion.
  String get signature {
    final ids = selectedSubToppings.map((s) => s.id).toList()..sort();
    return '${topping.id}:${ids.join(',')}';
  }
}
