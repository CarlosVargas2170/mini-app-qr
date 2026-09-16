import '../../../domain/entities/topping.dart';
import '../../mappers/topping_mapper.dart';

/// Grupo de toppings dentro de un item del menu ecosystem.
///
/// A diferencia de Legacy, aqui el tipo de seleccion no viene resuelto:
/// se infiere de [groupType]/[maxAllowed] en [toTopping].
class ToppingGroupDto {
  final int idToppingGroup;
  final String nameGroup;
  final String groupType;
  final int minRequired;
  final int maxAllowed;
  final bool isHidden;
  final List<EcosystemToppingDto> toppings;

  ToppingGroupDto({
    required this.idToppingGroup,
    required this.nameGroup,
    required this.groupType,
    required this.minRequired,
    required this.maxAllowed,
    required this.isHidden,
    required this.toppings,
  });

  factory ToppingGroupDto.fromJson(Map<String, dynamic> json) {
    return ToppingGroupDto(
      idToppingGroup: json['idToppingGroup'] ?? 0,
      nameGroup: json['nameGroup'] ?? '',
      groupType: json['type'] as String? ?? 'generico',
      minRequired: json['minRequired'] ?? 0,
      maxAllowed: json['maxAllowed'] ?? 0,
      isHidden: json['isHidden'] as bool? ?? false,
      toppings: (json['toppings'] as List<dynamic>? ?? const [])
          .map((t) => EcosystemToppingDto.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convierte el grupo a la entidad de dominio, o `null` si el grupo esta
  /// oculto o se queda sin opciones visibles.
  ///
  /// Regla de tipo: `groupType == 'extra'` -> [ToppingType.increment]
  /// (permite repetir la misma opcion, ej. "extra queso x3");
  /// `maxAllowed == 1` -> [ToppingType.radio]; en otro caso -> checkbox.
  Topping? toTopping() {
    if (isHidden) return null;

    final visibleToppings = toppings.where((t) => !t.isHidden).toList();
    final subToppings = visibleToppings.map((t) => t.toSubTopping()).toList();

    final type = groupType == 'extra'
        ? ToppingType.increment
        : (maxAllowed == 1 ? ToppingType.radio : ToppingType.checkbox);

    return buildToppingOrNull(
      id: idToppingGroup,
      name: nameGroup,
      type: type,
      minLimit: minRequired,
      maxLimit: maxAllowed,
      subToppings: subToppings,
    );
  }
}

class EcosystemToppingDto {
  final int idTopping;
  final String nameTopping;
  final double price;
  final String? sku;
  final bool isHidden;

  EcosystemToppingDto({
    required this.idTopping,
    required this.nameTopping,
    required this.price,
    this.sku,
    required this.isHidden,
  });

  factory EcosystemToppingDto.fromJson(Map<String, dynamic> json) {
    return EcosystemToppingDto(
      idTopping: json['idTopping'] ?? 0,
      nameTopping: json['nameTopping'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      sku: json['sku'] as String?,
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }

  SubTopping toSubTopping() => mapSubTopping({
        'id': idTopping,
        'name': nameTopping,
        'price': price,
        'sku': sku,
      });
}
