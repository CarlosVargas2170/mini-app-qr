/// Tipo de seleccion de un grupo de toppings.
///
/// Los nombres coinciden exactamente con el string que envian ambos
/// proveedores (`checkbox`, `radio`, `increment`), por lo que se puede
/// parsear con `ToppingType.values.byName(raw)` sin tabla de traduccion.
enum ToppingType { checkbox, radio, increment }

/// Entidad de dominio que representa un grupo de toppings de un producto
/// (ej. "Elige tu salsa", "Extras").
class Topping {
  final int id;
  final String name;
  final int minLimit;
  final int maxLimit;
  final ToppingType type;
  final List<SubTopping> subToppings;

  const Topping({
    required this.id,
    required this.name,
    required this.minLimit,
    required this.maxLimit,
    required this.type,
    required this.subToppings,
  });

  /// Un grupo es obligatorio cuando exige al menos una seleccion.
  bool get isMandatory => minLimit > 0;

  /// Busca un sub-topping por id dentro de este grupo.
  SubTopping? subToppingById(int id) {
    for (final subTopping in subToppings) {
      if (subTopping.id == id) return subTopping;
    }
    return null;
  }
}

/// Opcion individual dentro de un [Topping] (ej. "Extra queso").
class SubTopping {
  final int id;
  final String name;
  final double price;
  final String? sku;

  const SubTopping({
    required this.id,
    required this.name,
    required this.price,
    this.sku,
  });
}
