import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/app_settings.dart';
import '../../domain/usecases/get_merchant_info.dart';
import '../../domain/usecases/get_product.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final GetProductUseCase _getProduct;
  final GetMerchantInfoUseCase _getMerchant;

  HomeCubit({
    required GetProductUseCase getProduct,
    required GetMerchantInfoUseCase getMerchant,
  })  : _getProduct = getProduct,
        _getMerchant = getMerchant,
        super(const HomeState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(status: HomeStatus.loading, errorMessage: null));

    try {
      final settings = AppSettings();
      final product = await _getProduct(
        settings.merchantId,
        settings.productId,
      );
      final merchant = await _getMerchant(settings.merchantId);

      emit(state.copyWith(
        status: HomeStatus.loaded,
        product: product,
        merchantName: merchant.name,
      ));
    } catch (e) {
      debugPrint('[HomeCubit] load FAILED: $e');
      emit(state.copyWith(
        status: HomeStatus.error,
        errorMessage: 'No se pudo cargar el producto.\n${e.toString()}',
      ));
    }
  }
}
