import 'package:dio/dio.dart';

import '../../core/config/app_settings.dart';
import '../../core/config/merchant_config.dart';
import '../datasources/ecosystem_product_data_source.dart';
import '../datasources/legacy_product_data_source.dart';
import '../datasources/product_data_source.dart';

/// Factory que crea el [ProductDataSource] correcto según el
/// [MerchantConfig.provider].
///
/// - [ProductProviderType.legacy] → [LegacyProductDataSource]
/// - [ProductProviderType.ecosystem] → [EcosystemProductDataSource]
class ProductDataSourceFactory {
  ProductDataSourceFactory();

  /// Crea un Dio configurado para consultar el endpoint
  /// `GET /api/merchants/{id}` y obtener la configuración del merchant.
  Dio createDioForMerchantConfig() {
    final settings = AppSettings();
    return Dio(BaseOptions(
      baseUrl: settings.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Authorization': 'Bearer ${settings.bearerToken}',
        'Content-Type': 'application/json',
      },
    ));
  }

  /// Crea un [ProductDataSource] configurado para el merchant especificado.
  ProductDataSource create(MerchantConfig config) {
    final dio = Dio(BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Authorization': 'Bearer ${config.bearerToken}',
        'Content-Type': 'application/json',
      },
    ));

    if (config.isLegacy) {
      return LegacyProductDataSource(
        dio,
        config.merchantId,
        config.billingType,
      );
    }

    return EcosystemProductDataSource(
      dio,
      config.companyId!,
      config.channelId!,
      config.storeId!,
      config.merchantId,
      config.billingType,
    );
  }
}
