import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Obtiene un producto especifico de un comercio.
class GetProductUseCase {
  final ProductRepository _repository;

  GetProductUseCase(this._repository);

  Future<Product> call(int merchantId, int productId) =>
      _repository.getProduct(merchantId, productId);
}
