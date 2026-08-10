import 'package:flutter/foundation.dart';

import '../../core/config/merchant_config_factory.dart';
import '../../data/factories/product_data_source_factory.dart';
import '../../data/datasources/product_data_source.dart';
import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/merchant.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final ProductDataSourceFactory _dataSourceFactory;

  ProductRepositoryImpl(this._dataSourceFactory);

  @override
  Future<domain.Product> getProduct(int merchantId, int productId) async {
    final dataSource = await _createDataSource(merchantId);
    return dataSource.getProduct(productId);
  }

  @override
  Future<List<domain.Product>> getProducts(int merchantId) async {
    final dataSource = await _createDataSource(merchantId);
    return dataSource.getProducts();
  }

  @override
  Future<Merchant> getMerchantInfo(int merchantId) async {
    final dataSource = await _createDataSource(merchantId);
    return dataSource.getMerchantInfo();
  }

  /// Obtiene la config del merchant desde el backend y crea el DataSource
  /// correcto (legacy o ecosystem).
  Future<ProductDataSource> _createDataSource(int merchantId) async {
    // Consultar merchant desde backend (trae config + external IDs)
    final dio = _dataSourceFactory.createDioForMerchantConfig();
    final response = await dio.get('/merchants/$merchantId');
    final json = response.data as Map<String, dynamic>;

    debugPrint('[ProductRepo] Merchant $merchantId response: '
        'externalSystem=${json['configuration']?['externalSystem']}, '
        'companyExternalId=${json['companyExternalId']}, '
        'companyChannelExternalId=${json['companyChannelExternalId']}, '
        'merchantExternalId=${json['merchantExternalId']}, '
        'name=${json['name']}');

    final config = MerchantConfigFactory.create(json);
    return _dataSourceFactory.create(config);
  }
}
