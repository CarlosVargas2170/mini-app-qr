/// Entidad de dominio que representa la informacion de un comercio.
class Merchant {
  final int id;
  final String name;
  final String? urlLogo;

  const Merchant({
    required this.id,
    required this.name,
    this.urlLogo,
  });
}
