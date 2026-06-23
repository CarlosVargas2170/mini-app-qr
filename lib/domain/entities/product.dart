/// Entidad de dominio que representa un producto del comercio.
class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final double? oldPrice;
  final String urlImage;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.urlImage,
  });
}
