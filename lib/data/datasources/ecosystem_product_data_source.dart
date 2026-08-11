import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/product.dart' as domain;
import '../../domain/entities/merchant.dart' as domain;
import '../models/ecosystem/menu_response_dto.dart';
import 'product_data_source.dart';

/// DataSource para el endpoint ecosystem (merchant_panel).
///
/// Endpoint:
/// `GET /ecosystem/companies/{companyId}/channels/{channelId}/menu?storeId={storeId}`
class EcosystemProductDataSource implements ProductDataSource {
  final Dio _dio;
  final int _companyId;
  final int _channelId;
  final int _storeId;
  final int _merchantId;

  EcosystemProductDataSource(
    this._dio,
    this._companyId,
    this._channelId,
    this._storeId,
    this._merchantId,
  );

  String get _menuPath =>
      '/ecosystem/companies/$_companyId/channels/$_channelId/menu?storeId=$_storeId';

  @override
  Future<List<domain.Product>> getProducts() async {
    debugPrint(
        '[EcosystemDS] Consultando menú: baseUrl=${_dio.options.baseUrl} path=$_menuPath');
    final response = await _dio.get(_menuPath);
    final menuResponse =
        MenuResponseDto.fromJson(response.data as Map<String, dynamic>);

    final products = <domain.Product>[];

    for (final item in menuResponse.data.items) {
      if (item.pccsStatus == 'inactive') {
        debugPrint(
            '[EcosystemDS] Producto oculto: "${item.nameProduct}" (${item.hiddenReason ?? "sin razón"})');
        continue;
      }

      final basePrice = item.basePrice;
      final effectivePrice = item.effectivePrice;

      products.add(domain.Product(
        id: item.idProduct,
        merchantId: _merchantId,
        name: item.nameProduct,
        description: item.description,
        price: effectivePrice,
        oldPrice: basePrice != effectivePrice ? basePrice : null,
        urlImage: item.imageUrl,
      ));
    }

    debugPrint(
        '[EcosystemDS] ${products.length} productos visibles de ${menuResponse.data.total} totales '
        '(merchant $_merchantId, store $_storeId)');

    return products;
  }

  @override
  Future<domain.Product> getProduct(int productId) async {
    // Buscar en el menú completo por ID
    final products = await getProducts();
    final product = products.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception(
          'Producto $productId no encontrado en merchant $_merchantId'),
    );
    return product;
  }

  @override
  Future<domain.Merchant> getMerchantInfo() async {
    final response = await _dio.get(_menuPath);
    final menuResponse =
        MenuResponseDto.fromJson(response.data as Map<String, dynamic>);
    final storeName = menuResponse.data.store.nameStore;

    return domain.Merchant(
      id: _merchantId,
      name: storeName,
    );
  }
}
