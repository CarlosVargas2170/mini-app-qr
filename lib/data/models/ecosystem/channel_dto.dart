/// Canal del menú ecosystem.
class ChannelDto {
  final int idCompanyChannel;
  final String alias;
  final int isActive;

  ChannelDto({
    required this.idCompanyChannel,
    required this.alias,
    required this.isActive,
  });

  factory ChannelDto.fromJson(Map<String, dynamic> json) {
    return ChannelDto(
      idCompanyChannel: json['idCompanyChannel'] ?? 0,
      alias: json['alias'] ?? '',
      isActive: json['isActive'] ?? 1,
    );
  }
}
