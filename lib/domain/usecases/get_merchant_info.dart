import '../entities/merchant.dart';
import '../repositories/product_repository.dart';

/// Obtiene la informacion basica de un comercio.
class GetMerchantInfoUseCase {
  final ProductRepository _repository;

  GetMerchantInfoUseCase(this._repository);

  Future<Merchant> call(int merchantId) =>
      _repository.getMerchantInfo(merchantId);
}
