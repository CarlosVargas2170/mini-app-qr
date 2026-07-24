/// Entidad de dominio que representa un producto del comercio.
class Product {
  final int id;
  final int merchantId;
  final String name;
  final String description;
  final double price;
  final double? oldPrice;
  final String urlImage;

  const Product({
    required this.id,
    this.merchantId = 0,
    required this.name,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.urlImage,
  });

  Product copyWith({
    int? id,
    int? merchantId,
    String? name,
    String? description,
    double? price,
    double? oldPrice,
    String? urlImage,
  }) {
    return Product(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      oldPrice: oldPrice ?? this.oldPrice,
      urlImage: urlImage ?? this.urlImage,
    );
  }
}
