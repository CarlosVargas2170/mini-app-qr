import '../../../domain/entities/topping.dart';
import 'category_dto.dart';
import 'topping_group_dto.dart';

/// Item individual del menú ecosystem.
class MenuItemDto {
  final int idProduct;
  final String nameProduct;
  final String description;
  final String imageUrl;
  final String? sku;
  final CategoryDto category;
  final double basePrice;
  final double? channelPrice;
  final double? storeChannelPrice;
  final double effectivePrice;
  final bool isHidden;
  final String? hiddenReason;
  final String? pccsStatus;
  final List<ToppingGroupDto> toppingGroups;

  MenuItemDto({
    required this.idProduct,
    required this.nameProduct,
    required this.description,
    required this.imageUrl,
    this.sku,
    required this.category,
    required this.basePrice,
    this.channelPrice,
    this.storeChannelPrice,
    required this.effectivePrice,
    required this.isHidden,
    this.hiddenReason,
    this.pccsStatus,
    this.toppingGroups = const [],
  });

  factory MenuItemDto.fromJson(Map<String, dynamic> json) {
    return MenuItemDto(
      idProduct: json['idProduct'] ?? 0,
      nameProduct: json['nameProduct'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      sku: json['sku'] as String?,
      category: CategoryDto.fromJson(json['category'] as Map<String, dynamic>),
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      channelPrice: (json['channelPrice'] as num?)?.toDouble(),
      storeChannelPrice: (json['storeChannelPrice'] as num?)?.toDouble(),
      effectivePrice: (json['effectivePrice'] as num?)?.toDouble() ?? 0,
      isHidden: json['isHidden'] == true,
      hiddenReason: json['hiddenReason'] as String?,
      pccsStatus: json['pccsStatus'] as String?,
      toppingGroups: (json['toppingGroups'] as List<dynamic>? ?? const [])
          .map((g) => ToppingGroupDto.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convierte los grupos del menú a toppings de dominio, descartando
  /// grupos ocultos o sin opciones visibles. `null` si no queda ninguno.
  List<Topping>? toToppings() {
    final toppings =
        toppingGroups.map((g) => g.toTopping()).whereType<Topping>().toList();
    return toppings.isEmpty ? null : toppings;
  }
}
