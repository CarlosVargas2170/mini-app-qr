import '../../domain/entities/topping.dart';

/// Utilidades de mapeo de toppings compartidas entre los proveedores Legacy
/// y Ecosystem.
///
/// Legacy entrega el `type` de cada grupo ya resuelto (`checkbox`/`radio`/
/// `increment`), mientras que Ecosystem lo infiere a partir de
/// `groupType`/`maxAllowed` antes de llegar aqui. Ambos proveedores
/// terminan construyendo la entidad de dominio con [buildToppingOrNull] y
/// [mapSubTopping], para no duplicar la regla de "descartar grupos sin
/// opciones visibles".

/// Convierte la lista `toppings` nativa del proveedor Legacy
/// (`GET /v1/merchants/{id}/products-categories`) en toppings de dominio.
///
/// Devuelve `null` si [raw] es `null` o queda vacia tras filtrar grupos sin
/// sub-toppings.
List<Topping>? mapLegacyToppings(List<dynamic>? raw) {
  if (raw == null || raw.isEmpty) return null;

  final toppings = <Topping>[];
  for (final entry in raw) {
    final map = entry as Map<String, dynamic>;
    final subToppingsRaw = map['subToppings'] as List<dynamic>? ?? const [];
    final subToppings = subToppingsRaw
        .map((s) => mapSubTopping(s as Map<String, dynamic>))
        .toList();

    final topping = buildToppingOrNull(
      id: map['id'] as int,
      name: map['name'] as String? ?? '',
      type: parseToppingType(map['type'] as String?),
      minLimit: map['minLimit'] as int? ?? 0,
      maxLimit: map['maxLimit'] as int? ?? 0,
      subToppings: subToppings,
    );
    if (topping != null) toppings.add(topping);
  }

  return toppings.isEmpty ? null : toppings;
}

/// Parsea el string de tipo de grupo (`checkbox`/`radio`/`increment`).
/// Un valor desconocido o ausente cae a [ToppingType.checkbox] para no
/// bloquear la seleccion del producto por un dato inesperado del backend.
ToppingType parseToppingType(String? raw) {
  if (raw == null) return ToppingType.checkbox;
  return ToppingType.values.firstWhere(
    (t) => t.name == raw,
    orElse: () => ToppingType.checkbox,
  );
}

SubTopping mapSubTopping(Map<String, dynamic> map) {
  return SubTopping(
    id: map['id'] as int,
    name: map['name'] as String? ?? '',
    price: double.tryParse(map['price']?.toString() ?? '0') ?? 0.0,
    sku: map['sku'] as String?,
  );
}

/// Construye un [Topping] o devuelve `null` si, tras filtrar opciones
/// ocultas, el grupo se queda sin sub-toppings seleccionables.
Topping? buildToppingOrNull({
  required int id,
  required String name,
  required ToppingType type,
  required int minLimit,
  required int maxLimit,
  required List<SubTopping> subToppings,
}) {
  if (subToppings.isEmpty) return null;
  return Topping(
    id: id,
    name: name,
    minLimit: minLimit,
    maxLimit: maxLimit,
    type: type,
    subToppings: subToppings,
  );
}
