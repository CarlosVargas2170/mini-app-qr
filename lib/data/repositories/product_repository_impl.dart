import 'package:flutter/foundation.dart';

import '../../core/config/merchant_config_factory.dart';
import '../../data/factories/product_data_source_factory.dart';
import '../../data/datasources/product_data_source.dart';
import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/merchant.dart';
import '../../domain/repositories/product_repository.dart';

/// Implementación del repositorio de productos con soporte para múltiples
/// proveedores (legacy y ecosystem) mediante [ProductDataSourceFactory].
///
/// Mantiene un caché interno de [ProductDataSource] por merchant para evitar
/// consultas redundantes al endpoint `/merchants/{id}` en cada ciclo de polling.
class ProductRepositoryImpl implements ProductRepository {
  final ProductDataSourceFactory _dataSourceFactory;

  /// Caché de DataSources por merchantId.
  /// Se crean una sola vez y se reutilizan en llamadas posteriores.
  final Map<int, ProductDataSource> _dataSourceCache = {};

  ProductRepositoryImpl(this._dataSourceFactory);

  @override
  Future<domain.Product> getProduct(int merchantId, int productId) async {
    final dataSource = await _getOrCreateDataSource(merchantId);
    return dataSource.getProduct(productId);
  }

  @override
  Future<List<domain.Product>> getProducts(int merchantId) async {
    final dataSource = await _getOrCreateDataSource(merchantId);
    return dataSource.getProducts();
  }

  @override
  Future<Merchant> getMerchantInfo(int merchantId) async {
    final dataSource = await _getOrCreateDataSource(merchantId);
    return dataSource.getMerchantInfo();
  }

  /// Obtiene (o crea y cachea) el [ProductDataSource] para un merchant.
  ///
  /// - Si ya está en caché → reutiliza (sin llamada HTTP adicional)
  /// - Si no está en caché → consulta `/merchants/{id}`, crea config y DataSource
  Future<ProductDataSource> _getOrCreateDataSource(int merchantId) async {
    // 1. Verificar caché
    if (_dataSourceCache.containsKey(merchantId)) {
      debugPrint('[ProductRepo] Merchant $merchantId → DataSource desde CACHÉ');
      return _dataSourceCache[merchantId]!;
    }

    // 2. Consultar configuración desde backend (solo la primera vez)
    debugPrint(
        '[ProductRepo] Merchant $merchantId → consultando configuración...');
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
    final dataSource = _dataSourceFactory.create(config);

    // 3. Cachear para futuras llamadas
    _dataSourceCache[merchantId] = dataSource;
    debugPrint(
        '[ProductRepo] Merchant $merchantId → DataSource CACHEADO (${config.isLegacy ? "legacy" : "ecosystem"})');

    return dataSource;
  }
}
