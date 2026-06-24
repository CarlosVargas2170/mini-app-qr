import 'package:equatable/equatable.dart';
import '../../domain/entities/product.dart';

enum HomeStatus { initial, loading, loaded, error }

/// Modo de visualizacion en la pantalla principal.
/// - [idle]: reposo (pantalla negra / espera).
/// - [attract]: video de atraccion cuando el robot esta cerca.
/// - [product]: tarjeta del producto y boton de pago.
enum DisplayMode { idle, attract, product }

class HomeState extends Equatable {
  final HomeStatus status;
  final DisplayMode displayMode;
  final Product? product;
  final String merchantName;
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.displayMode = DisplayMode.idle,
    this.product,
    this.merchantName = 'Mi Tienda',
    this.errorMessage,
  });

  HomeState copyWith({
    HomeStatus? status,
    DisplayMode? displayMode,
    Product? product,
    String? merchantName,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      displayMode: displayMode ?? this.displayMode,
      product: product ?? this.product,
      merchantName: merchantName ?? this.merchantName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, displayMode, product, merchantName, errorMessage];
}
