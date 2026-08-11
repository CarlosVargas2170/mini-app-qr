/// Moneda del menú ecosystem.
class CurrencyDto {
  final String code;
  final String name;
  final String symbol;

  CurrencyDto({
    required this.code,
    required this.name,
    required this.symbol,
  });

  factory CurrencyDto.fromJson(Map<String, dynamic> json) {
    return CurrencyDto(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      symbol: json['symbol'] ?? '',
    );
  }
}
