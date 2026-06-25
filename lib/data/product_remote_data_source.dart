import 'package:dio/dio.dart';
import '../../core/config/app_settings.dart';

/// Modelo simple de producto desde el backend.
class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final double? oldPrice;
  final String urlImage;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.urlImage,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
      oldPrice: json['oldPrice'] != null
          ? double.tryParse(json['oldPrice'].toString())
          : null,
      urlImage: json['urlImage'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'oldPrice': oldPrice,
        'urlImage': urlImage,
      };
}

/// Data source para obtener productos del backend.
class ProductRemoteDataSource {
  final Dio _dio;

  ProductRemoteDataSource(this._dio);

  /// Obtiene un producto específico por ID.
  /// Endpoint: GET /v1/merchants/:merchantId/products/:productId
  Future<Product> getProduct(int merchantId, int productId) async {
    final response = await _dio.get(
      '/v1/merchants/$merchantId/products/$productId',
    );
    return Product.fromJson(response.data as Map<String, dynamic>);
  }

  /// Obtiene categorías con productos del merchant.
  /// Endpoint: GET /v1/merchants/:merchantId/products-categories?include=products&filter=withProducts
  Future<List<Product>> getProducts(int merchantId) async {
    final response = await _dio.get(
      '/v1/merchants/$merchantId/products-categories',
      queryParameters: {
        'include': 'products',
        'filter': 'withProducts',
      },
    );

    final List<dynamic> categories = response.data;
    final List<Product> products = [];

    for (final cat in categories) {
      final List<dynamic>? prods = cat['products'];
      if (prods != null) {
        for (final p in prods) {
          products.add(Product.fromJson(p as Map<String, dynamic>));
        }
      }
    }

    return products;
  }

  /// Obtiene info del merchant (para el nombre y logo).
  Future<Map<String, dynamic>> getMerchantInfo(int merchantId) async {
    final response = await _dio.get('/merchants/$merchantId');
    return response.data as Map<String, dynamic>;
  }
}

/// Crea un Dio pre-configurado con el Bearer token de [AppSettings].
Dio createAuthenticatedDio() {
  final settings = AppSettings();
  final dio = Dio(BaseOptions(
    baseUrl: settings.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'Authorization': 'Bearer ${settings.bearerToken}',
      'Content-Type': 'application/json',
    },
  ));
  return dio;
}
