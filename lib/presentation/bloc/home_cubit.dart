import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/app_settings.dart';
import '../../domain/usecases/get_merchant_info.dart';
import '../../domain/usecases/get_product.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final GetProductUseCase _getProduct;
  final GetMerchantInfoUseCase _getMerchant;

  Timer? _inactivityTimer;

  /// Tiempo de inactividad antes de volver a [DisplayMode.attract].
  static const _inactivityTimeout = Duration(seconds: 60);

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
    debugPrint('[HomeCubit] load() iniciado');

    try {
      final settings = AppSettings();
      debugPrint('[HomeCubit] merchantId=${settings.merchantId}, productId=${settings.productId}');

      debugPrint('[HomeCubit] Llamando GetProductUseCase...');
      final product = await _getProduct(
        settings.merchantId,
        settings.productId,
      );
      debugPrint('[HomeCubit] Producto obtenido OK: id=${product.id}, nombre="${product.name}", precio=${product.price}');

      debugPrint('[HomeCubit] Llamando GetMerchantInfoUseCase...');
      final merchant = await _getMerchant(settings.merchantId);
      debugPrint('[HomeCubit] Merchant obtenido OK: nombre="${merchant.name}"');

      emit(state.copyWith(
        status: HomeStatus.loaded,
        displayMode: DisplayMode.attract,
        product: product,
        merchantName: merchant.name,
      ));
      debugPrint('[HomeCubit] Estado emitido: loaded + attract');
    } catch (e, stack) {
      debugPrint('[HomeCubit] load FAILED: $e');
      debugPrint('[HomeCubit] StackTrace: $stack');
      emit(state.copyWith(
        status: HomeStatus.error,
        errorMessage: 'No se pudo cargar el producto.\n${e.toString()}',
      ));
    }
  }

  /// Muestra el video de atraccion (robot cerca de persona).
  void showAttract() {
    debugPrint('[HomeCubit] showAttract() llamado');
    _cancelInactivityTimer();
    if (state.status == HomeStatus.loaded) {
      emit(state.copyWith(displayMode: DisplayMode.attract));
      debugPrint('[HomeCubit] Estado emitido: displayMode=attract');
    } else {
      debugPrint('[HomeCubit] showAttract() ignorado: status=${state.status} (aun no esta loaded)');
    }
  }

  /// Muestra el producto y programa el timer de inactividad.
  void showProduct() {
    debugPrint('[HomeCubit] showProduct() llamado');
    _cancelInactivityTimer();
    if (state.status == HomeStatus.loaded) {
      emit(state.copyWith(displayMode: DisplayMode.product));
      debugPrint('[HomeCubit] Estado emitido: displayMode=product');
      _startInactivityTimer();
    } else {
      debugPrint('[HomeCubit] showProduct() ignorado: status=${state.status} (aun no esta loaded)');
    }
  }

  /// Vuelve a reposo / espera.
  void showIdle() {
    debugPrint('[HomeCubit] showIdle() llamado');
    _cancelInactivityTimer();
    if (state.status == HomeStatus.loaded) {
      emit(state.copyWith(displayMode: DisplayMode.idle));
      debugPrint('[HomeCubit] Estado emitido: displayMode=idle');
    } else {
      debugPrint('[HomeCubit] showIdle() ignorado: status=${state.status} (aun no esta loaded)');
    }
  }

  void _startInactivityTimer() {
    debugPrint('[HomeCubit] Timer de inactividad iniciado (${_inactivityTimeout.inSeconds}s)');
    _inactivityTimer = Timer(_inactivityTimeout, () {
      if (!isClosed) {
        debugPrint('[HomeCubit] Timer de inactividad expirado -> volviendo a attract');
        showAttract();
      }
    });
  }

  void _cancelInactivityTimer() {
    if (_inactivityTimer != null) {
      debugPrint('[HomeCubit] Timer de inactividad cancelado');
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
    }
  }

  @override
  Future<void> close() {
    _cancelInactivityTimer();
    return super.close();
  }
}
