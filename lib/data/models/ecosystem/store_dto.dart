/// Tienda del menú ecosystem.
class StoreDto {
  final int idStore;
  final String nameStore;

  StoreDto({
    required this.idStore,
    required this.nameStore,
  });

  factory StoreDto.fromJson(Map<String, dynamic> json) {
    return StoreDto(
      idStore: json['idStore'] ?? 0,
      nameStore: json['nameStore'] ?? '',
    );
  }
}
