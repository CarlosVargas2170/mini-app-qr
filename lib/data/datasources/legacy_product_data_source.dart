import 'package:dio/dio.dart';

import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/merchant.dart' as domain;
import 'product_data_source.dart';

/// DataSource para el endpoint legacy (patio_service).
///
/// Endpoint: `GET /v1/merchants/{id}/products-categories`
class LegacyProductDataSource implements ProductDataSource {
  final Dio _dio;
  final int _merchantId;

  LegacyProductDataSource(this._dio, this._merchantId);

  @override
  Future<List<domain.Product>> getProducts() async {
    final response = await _dio.get(
      '/v1/merchants/$_merchantId/products-categories',
      queryParameters: {
        'include': 'products',
        'filter': 'withProducts',
      },
    );

    final List<dynamic> categories = response.data;
    final List<domain.Product> products = [];

    for (final cat in categories) {
      final prods = cat['products'] as List?;
      if (prods != null) {
        for (final p in prods) {
          products.add(_mapToProduct(p as Map<String, dynamic>));
        }
      }
    }

    return products;
  }

  @override
  Future<domain.Product> getProduct(int productId) async {
    final response = await _dio.get(
      '/v1/merchants/$_merchantId/products/$productId',
    );
    return _mapToProduct(response.data as Map<String, dynamic>);
  }

  @override
  Future<domain.Merchant> getMerchantInfo() async {
    final response = await _dio.get('/merchants/$_merchantId');
    final json = response.data as Map<String, dynamic>;
    return domain.Merchant(
      id: _merchantId,
      name: json['name'] ?? '',
      urlLogo: json['urlLogo'] as String?,
    );
  }

  domain.Product _mapToProduct(Map<String, dynamic> json) {
    return domain.Product(
      id: json['id'] ?? 0,
      merchantId: _merchantId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      oldPrice: json['oldPrice'] != null
          ? double.tryParse(json['oldPrice'].toString())
          : null,
      urlImage: json['urlImage'] ?? '',
    );
  }
}
