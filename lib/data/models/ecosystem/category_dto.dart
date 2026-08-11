/// Categoría de un producto en el menú ecosystem.
class CategoryDto {
  final int idCategory;
  final String nameCategory;
  final String? imageUrl;
  final int order;

  CategoryDto({
    required this.idCategory,
    required this.nameCategory,
    this.imageUrl,
    required this.order,
  });

  factory CategoryDto.fromJson(Map<String, dynamic> json) {
    return CategoryDto(
      idCategory: json['idCategory'] ?? 0,
      nameCategory: json['nameCategory'] ?? '',
      imageUrl: json['imageUrl'] as String?,
      order: json['order'] ?? 0,
    );
  }
}
