import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/merchant.dart';
import '../../domain/repositories/product_repository.dart';
import '../product_remote_data_source.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDataSource _remote;

  ProductRepositoryImpl(this._remote);

  @override
  Future<domain.Product> getProduct(int merchantId, int productId) async {
    final dto = await _remote.getProduct(merchantId, productId);
    return _mapToDomain(dto, merchantId);
  }

  @override
  Future<List<domain.Product>> getProducts(int merchantId) async {
    final dtos = await _remote.getProducts(merchantId);
    return dtos.map((dto) => _mapToDomain(dto, merchantId)).toList();
  }

  @override
  Future<Merchant> getMerchantInfo(int merchantId) async {
    final json = await _remote.getMerchantInfo(merchantId);
    return Merchant(
      id: merchantId,
      name: json['name'] ?? '',
      urlLogo: json['urlLogo'] as String?,
    );
  }

  domain.Product _mapToDomain(Product dto, int merchantId) {
    return domain.Product(
      id: dto.id,
      merchantId: merchantId,
      name: dto.name,
      description: dto.description,
      price: dto.price,
      oldPrice: dto.oldPrice,
      urlImage: dto.urlImage,
    );
  }
}
