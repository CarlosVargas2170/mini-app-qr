import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/merchant.dart' as domain;

/// Interfaz común para obtener productos de diferentes proveedores.
///
/// Implementaciones:
/// - [LegacyProductDataSource]: endpoint legacy
/// - [EcosystemProductDataSource]: endpoint ecosystem
abstract class ProductDataSource {
  Future<List<domain.Product>> getProducts();

  Future<domain.Product> getProduct(int productId);

  Future<domain.Merchant> getMerchantInfo();
}
