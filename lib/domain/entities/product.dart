import 'topping.dart';

/// Entidad de dominio que representa un producto del comercio.
class Product {
  final int id;
  final int merchantId;
  final String name;
  final String description;
  final double price;
  final double? oldPrice;
  final String urlImage;

  /// Grupos de toppings disponibles para este producto. `null` o vacio
  /// significa que el producto no tiene modificadores configurados.
  final List<Topping>? toppings;

  const Product({
    required this.id,
    this.merchantId = 0,
    required this.name,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.urlImage,
    this.toppings,
  });

  bool get hasToppings => toppings != null && toppings!.isNotEmpty;

  /// Busca un grupo de toppings por id.
  Topping? toppingById(int id) {
    if (toppings == null) return null;
    for (final topping in toppings!) {
      if (topping.id == id) return topping;
    }
    return null;
  }

  Product copyWith({
    int? id,
    int? merchantId,
    String? name,
    String? description,
    double? price,
    double? oldPrice,
    String? urlImage,
    List<Topping>? toppings,
  }) {
    return Product(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      urlImage: urlImage ?? this.urlImage,
      toppings: toppings ?? this.toppings,
    );
  }
}
