import 'product.dart';
import 'selected_topping.dart';

/// Una linea del carrito: un producto con una configuracion de toppings
/// concreta y su cantidad.
///
/// Sustituye al antiguo `Map<String,int>` por producto: con toppings, el
/// mismo producto puede aparecer en varias lineas con configuraciones
/// distintas, cada una con su propio [id] e [totalPrice].
class CartItem {
  final String id;
  final Product product;
  final int quantity;

  /// Solo incluye toppings con al menos una opcion seleccionada (grupos
  /// `checkbox`/`radio`). Los grupos `increment` se llevan en
  /// [extraQuantities].
  final List<SelectedTopping> selectedToppings;

  /// `toppingId -> subToppingId -> cantidad`, para grupos `increment`.
  final Map<int, Map<int, int>> extraQuantities;

  /// Precio de una unidad, incluyendo addons de toppings.
  final double unitPrice;

  /// `unitPrice * quantity`.
  final double totalPrice;

  const CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.selectedToppings,
    required this.extraQuantities,
    required this.unitPrice,
    required this.totalPrice,
  });

  /// Construye una linea de carrito calculando `unitPrice`/`totalPrice` a
  /// partir del producto y la configuracion elegida.
  ///
  /// [id] debe ser unico dentro del carrito (ej. timestamp o uuid); lo
  /// decide quien agrega la linea.
  factory CartItem.configured({
    required String id,
    required Product product,
    required int quantity,
    required List<SelectedTopping> selectedToppings,
    required Map<int, Map<int, int>> extraQuantities,
  }) {
    final unitPrice = unitPriceFor(
      product: product,
      selectedToppings: selectedToppings,
      extraQuantities: extraQuantities,
    );
    return CartItem(
      id: id,
      product: product,
      quantity: quantity,
      selectedToppings: selectedToppings,
      extraQuantities: extraQuantities,
      unitPrice: unitPrice,
      totalPrice: unitPrice * quantity,
    );
  }

  /// Precio de una unidad del producto con la configuracion dada: precio
  /// base + subtoppings elegidos (checkbox/radio, cuentan una vez cada uno)
  /// + subtoppings incrementales (cuentan por la cantidad elegida).
  ///
  /// Los subtoppings de [extraQuantities] no traen su precio consigo (solo
  /// id y cantidad), asi que se busca en `product.toppings`. Un id que ya
  /// no exista en el producto simplemente no suma precio.
  static double unitPriceFor({
    required Product product,
    required List<SelectedTopping> selectedToppings,
    required Map<int, Map<int, int>> extraQuantities,
  }) {
    double addons = 0;

    for (final selected in selectedToppings) {
      for (final subTopping in selected.selectedSubToppings) {
        addons += subTopping.price;
      }
    }

    extraQuantities.forEach((toppingId, subToppingQuantities) {
      final topping = product.toppingById(toppingId);
      if (topping == null) return;
      subToppingQuantities.forEach((subToppingId, qty) {
        final subTopping = topping.subToppingById(subToppingId);
        if (subTopping != null) addons += subTopping.price * qty;
      });
    });

    return product.price + addons;
  }

  bool get hasCustomConfiguration =>
      selectedToppings.isNotEmpty || extraQuantities.isNotEmpty;

  /// Firma estable de la configuracion (toppings + extras), usada para
  /// decidir si dos lineas del mismo producto deben fusionarse en el
  /// carrito en vez de crear una linea nueva.
  String get configurationSignature {
    final toppingsSig = selectedToppings.map((s) => s.signature).toList()
      ..sort();

    final extrasSig = extraQuantities.entries.map((entry) {
      final subEntries = entry.value.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final subSig = subEntries.map((e) => '${e.key}=${e.value}').join(',');
      return '${entry.key}:[$subSig]';
    }).toList()
      ..sort();

    return '${product.id}|${toppingsSig.join(';')}|${extrasSig.join(';')}';
  }

  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    List<SelectedTopping>? selectedToppings,
    Map<int, Map<int, int>>? extraQuantities,
    double? unitPrice,
    double? totalPrice,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      selectedToppings: selectedToppings ?? this.selectedToppings,
      extraQuantities: extraQuantities ?? this.extraQuantities,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }
}
