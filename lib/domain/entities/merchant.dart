/// Entidad de dominio que representa la informacion de un comercio.
class Merchant {
  final int id;
  final String name;
  final String? urlLogo;
  final String billingType;

  const Merchant({
    required this.id,
    required this.name,
    this.urlLogo,
    this.billingType = 'none',
  });

  /// Indica si el comercio tiene habilitado algun sistema de facturacion.
  ///
  /// El backend usa `none` cuando el comercio no factura. Un valor ausente o
  /// vacio tambien se trata como no facturable para mantener compatibilidad.
  bool get usesBilling {
    final normalized = billingType.trim().toLowerCase();
    return normalized.isNotEmpty && normalized != 'none';
  }
}
