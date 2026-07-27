import '../../domain/entities/product.dart';
import '../config/product_filter_config.dart';

/// Cache en memoria de los productos cargados desde la API.
///
/// Actua como puente entre la capa de presentacion (HomeCubit)
/// y la capa de infraestructura (AppServer), permitiendo que
/// los endpoints HTTP consulten los productos sin acoplarse al Cubit.
class ProductCache {
  static final ProductCache _instance = ProductCache._();
  factory ProductCache() => _instance;
  ProductCache._();

  /// Todos los productos cargados (sin filtrar).
  List<Product> allProducts = [];

  /// Nombres de los merchants cargados (indice alineado con [loadedMerchantIds]).
  List<String> merchantNames = [];

  /// IDs de los merchants cargados exitosamente.
  List<int> loadedMerchantIds = [];

  /// Indica si los productos ya fueron cargados al menos una vez.
  bool get isLoaded => allProducts.isNotEmpty && loadedMerchantIds.isNotEmpty;

  /// Construye la respuesta para el endpoint GET /products.
  /// Agrupa productos por merchant e incluye su estado de visibilidad.
  Map<String, dynamic> buildProductsResponse(ProductFilterConfig filter) {
    final merchants = <Map<String, dynamic>>[];
    var totalProducts = 0;
    var visibleProducts = 0;

    for (var i = 0; i < loadedMerchantIds.length; i++) {
      final merchantId = loadedMerchantIds[i];
      final merchantName =
          i < merchantNames.length ? merchantNames[i] : 'Desconocido';
      final enabled = filter.isMerchantEnabled(merchantId);

      final merchantProducts =
          allProducts.where((p) => p.merchantId == merchantId).map((p) {
        final visible = filter.isProductVisible(p.id, merchantId);
        final pinned = filter.pinnedProducts.contains(p.id);
        return {
          'id': p.id,
          'name': p.name,
          'description': p.description,
          'price': p.price,
          'oldPrice': p.oldPrice,
          'urlImage': p.urlImage,
          'visible': visible,
          'pinned': pinned,
        };
      }).toList();

      totalProducts += merchantProducts.length;
      visibleProducts +=
          merchantProducts.where((p) => p['visible'] == true).length;

      merchants.add({
        'merchantId': merchantId,
        'merchantName': merchantName,
        'enabled': enabled,
        'productCount': merchantProducts.length,
        'visibleCount':
            merchantProducts.where((p) => p['visible'] == true).length,
        'products': merchantProducts,
      });
    }

    return {
      'merchants': merchants,
      'filterMode': filter.filterMode,
      'totalProducts': totalProducts,
      'visibleProducts': visibleProducts,
      'hiddenProducts': totalProducts - visibleProducts,
      'configuredMerchantIds':
          allProducts.map((p) => p.merchantId).toSet().toList(),
    };
  }

  /// Vacia el cache.
  void clear() {
    allProducts = [];
    merchantNames = [];
    loadedMerchantIds = [];
  }
}
