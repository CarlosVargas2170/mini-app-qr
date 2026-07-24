/// Configuracion de visibilidad de merchants y productos.
///
/// Controla que merchants y productos se muestran en el carrusel.
/// Se persiste junto con el resto de la configuracion de la app.
class ProductFilterConfig {
  /// Merchants habilitados (vacío = todos habilitados).
  Set<int> enabledMerchants;

  /// Productos ocultados (blacklist).
  Set<int> hiddenProducts;

  /// Productos forzados a mostrarse siempre (whitelist, prioridad máxima).
  Set<int> pinnedProducts;

  /// Modo de filtrado:
  /// - 'all': mostrar todo (default).
  /// - 'blacklist': ocultar los productos en [hiddenProducts].
  /// - 'whitelist': solo mostrar los productos en [pinnedProducts].
  String filterMode;

  ProductFilterConfig({
    Set<int>? enabledMerchants,
    Set<int>? hiddenProducts,
    Set<int>? pinnedProducts,
    this.filterMode = 'all',
  })  : enabledMerchants = enabledMerchants ?? {},
        hiddenProducts = hiddenProducts ?? {},
        pinnedProducts = pinnedProducts ?? {};

  /// Convierte a JSON para persistencia.
  Map<String, dynamic> toJson() => {
        'enabledMerchants': enabledMerchants.toList(),
        'hiddenProducts': hiddenProducts.toList(),
        'pinnedProducts': pinnedProducts.toList(),
        'filterMode': filterMode,
      };

  /// Crea desde JSON persistido.
  factory ProductFilterConfig.fromJson(Map<String, dynamic> json) {
    return ProductFilterConfig(
      enabledMerchants: _toIntSet(json['enabledMerchants']),
      hiddenProducts: _toIntSet(json['hiddenProducts']),
      pinnedProducts: _toIntSet(json['pinnedProducts']),
      filterMode: json['filterMode'] as String? ?? 'all',
    );
  }

  /// Determina si un producto debe mostrarse, dado su [productId] y [merchantId].
  bool isProductVisible(int productId, int merchantId) {
    // 1. Si el merchant está deshabilitado → no mostrar
    if (enabledMerchants.isNotEmpty && !enabledMerchants.contains(merchantId)) {
      return false;
    }

    // 2. Whitelist mode: solo pinned
    if (filterMode == 'whitelist') {
      return pinnedProducts.contains(productId);
    }

    // 3. Pinned products siempre se muestran (prioridad sobre blacklist)
    if (pinnedProducts.contains(productId)) {
      return true;
    }

    // 4. Blacklist mode: ocultar los que están en hiddenProducts
    if (filterMode == 'blacklist') {
      return !hiddenProducts.contains(productId);
    }

    // 5. All mode: mostrar todo
    return true;
  }

  /// Determina si un merchant está habilitado.
  bool isMerchantEnabled(int merchantId) {
    if (enabledMerchants.isEmpty) return true;
    return enabledMerchants.contains(merchantId);
  }

  /// Restablece todos los filtros.
  void reset() {
    enabledMerchants.clear();
    hiddenProducts.clear();
    pinnedProducts.clear();
    filterMode = 'all';
  }

  static Set<int> _toIntSet(dynamic value) {
    if (value is List) {
      return value.map((e) => (e as num).toInt()).toSet();
    }
    return {};
  }
}
