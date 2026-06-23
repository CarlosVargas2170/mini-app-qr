import 'package:equatable/equatable.dart';
import '../../domain/entities/product.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState extends Equatable {
  final HomeStatus status;
  final Product? product;
  final String merchantName;
  final String? errorMessage;

  const HomeState({
    this.status = HomeStatus.initial,
    this.product,
    this.merchantName = 'Mi Tienda',
    this.errorMessage,
  });

  HomeState copyWith({
    HomeStatus? status,
    Product? product,
    String? merchantName,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      product: product ?? this.product,
      merchantName: merchantName ?? this.merchantName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, product, merchantName, errorMessage];
}
