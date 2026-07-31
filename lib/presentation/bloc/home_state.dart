import 'package:equatable/equatable.dart';
import '../../domain/entities/product.dart';

enum HomeStatus { initial, loading, loaded, error }

/// Modo de visualizacion en la pantalla principal.
/// - [idle]: reposo (pantalla negra / espera).
/// - [attract]: video de atraccion cuando el robot esta cerca.
/// - [product]: carrusel de productos y boton de pago.
enum DisplayMode { idle, attract, product }

class HomeState extends Equatable {
  final HomeStatus status;
  final DisplayMode displayMode;
  final List<Product> products;
  final int currentIndex;
  final String merchantName;
  final List<String> merchantNames;
  final List<int> merchantIds;
  final String? errorMessage;

  /// Ruta del asset GIF que se muestra en modo [DisplayMode.attract].
  /// Por defecto `assets/images/attract.gif`.
  final String attractGifAsset;

  const HomeState({
    this.status = HomeStatus.initial,
    this.displayMode = DisplayMode.idle,
    this.products = const [],
    this.currentIndex = 0,
    this.merchantName = 'Mi Tienda',
    this.merchantNames = const [],
    this.merchantIds = const [],
    this.errorMessage,
    this.attractGifAsset = 'assets/images/attract.gif',
  });

  Product? get currentProduct =>
      products.isNotEmpty ? products[currentIndex] : null;

  /// Obtiene el nombre del merchant para un producto especifico.
  String getMerchantNameForProduct(Product product) {
    final index = merchantIds.indexOf(product.merchantId);
    if (index >= 0 && index < merchantNames.length) {
      return merchantNames[index];
    }
    return merchantName; // Fallback
  }

  HomeState copyWith({
    HomeStatus? status,
    DisplayMode? displayMode,
    List<Product>? products,
    int? currentIndex,
    String? merchantName,
    List<String>? merchantNames,
    List<int>? merchantIds,
    String? errorMessage,
    String? attractGifAsset,
  }) {
    return HomeState(
      status: status ?? this.status,
      displayMode: displayMode ?? this.displayMode,
      products: products ?? this.products,
      currentIndex: currentIndex ?? this.currentIndex,
      merchantName: merchantName ?? this.merchantName,
      merchantNames: merchantNames ?? this.merchantNames,
      merchantIds: merchantIds ?? this.merchantIds,
      errorMessage: errorMessage ?? this.errorMessage,
      attractGifAsset: attractGifAsset ?? this.attractGifAsset,
    );
  }

  @override
  List<Object?> get props => [
        status,
        displayMode,
        products,
        currentIndex,
        merchantName,
        merchantNames,
        merchantIds,
        errorMessage,
        attractGifAsset,
      ];
}
