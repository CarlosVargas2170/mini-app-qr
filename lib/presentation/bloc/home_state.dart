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
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.displayMode = DisplayMode.idle,
    this.products = const [],
    this.currentIndex = 0,
    this.merchantName = 'Mi Tienda',
    this.errorMessage,
  });

  Product? get currentProduct =>
      products.isNotEmpty ? products[currentIndex] : null;

  HomeState copyWith({
    HomeStatus? status,
    DisplayMode? displayMode,
    List<Product>? products,
    int? currentIndex,
    String? merchantName,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      displayMode: displayMode ?? this.displayMode,
      products: products ?? this.products,
      currentIndex: currentIndex ?? this.currentIndex,
      merchantName: merchantName ?? this.merchantName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, displayMode, products, currentIndex, merchantName, errorMessage];
}
