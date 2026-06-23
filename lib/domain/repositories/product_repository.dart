import '../entities/product.dart';
import '../entities/merchant.dart';

/// Contrato del repositorio de productos y comercios.
abstract class ProductRepository {
  Future<Product> getProduct(int merchantId, int productId);
  Future<List<Product>> getProducts(int merchantId);
  Future<Merchant> getMerchantInfo(int merchantId);
}
