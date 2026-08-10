import 'menu_item_dto.dart';
import 'channel_dto.dart';
import 'store_dto.dart';
import 'currency_dto.dart';

/// Respuesta completa del endpoint
/// `GET /ecosystem/companies/{id}/channels/{id}/menu?storeId={id}`
class MenuResponseDto {
  final bool success;
  final MenuDataDto data;
  final String message;

  MenuResponseDto({
    required this.success,
    required this.data,
    required this.message,
  });

  factory MenuResponseDto.fromJson(Map<String, dynamic> json) {
    return MenuResponseDto(
      success: json['success'] ?? false,
      data: MenuDataDto.fromJson(json['data'] as Map<String, dynamic>),
      message: json['message'] ?? '',
    );
  }
}

class MenuDataDto {
  final ChannelDto channel;
  final StoreDto store;
  final CurrencyDto currency;
  final int total;
  final int visible;
  final int hidden;
  final List<MenuItemDto> items;

  MenuDataDto({
    required this.channel,
    required this.store,
    required this.currency,
    required this.total,
    required this.visible,
    required this.hidden,
    required this.items,
  });

  factory MenuDataDto.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List? ?? [];
    return MenuDataDto(
      channel: ChannelDto.fromJson(json['channel'] as Map<String, dynamic>),
      store: StoreDto.fromJson(json['store'] as Map<String, dynamic>),
      currency: CurrencyDto.fromJson(json['currency'] as Map<String, dynamic>),
      total: json['total'] ?? 0,
      visible: json['visible'] ?? 0,
      hidden: json['hidden'] ?? 0,
      items: itemsList
          .map((e) => MenuItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
