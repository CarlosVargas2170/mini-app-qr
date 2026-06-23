import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Obtiene todos los productos de un comercio.
class GetProductsUseCase {
  final ProductRepository _repository;

  GetProductsUseCase(this._repository);

  Future<List<Product>> call(int merchantId) =>
      _repository.getProducts(merchantId);
}
