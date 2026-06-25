import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/app_settings.dart';
import '../../domain/entities/product.dart';
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
      final result = await _loadWithRetry();
      emit(state.copyWith(
        status: HomeStatus.loaded,
        displayMode: DisplayMode.attract,
        product: result.product,
        merchantName: result.merchantName,
      ));
      debugPrint('[HomeCubit] Estado emitido: loaded + attract');
    } catch (e, stack) {
      debugPrint('[HomeCubit] load FAILED (incluyendo retry): $e');
      debugPrint('[HomeCubit] StackTrace: $stack');
      emit(state.copyWith(
        status: HomeStatus.error,
        errorMessage: 'No se pudo cargar el producto.\n${e.toString()}',
      ));
    }
  }

  Future<({Product product, String merchantName})> _loadWithRetry() async {
    const maxRetries = 1;
    const retryDelay = Duration(seconds: 2);

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        debugPrint('[HomeCubit] Reintentando en ${retryDelay.inSeconds}s... (intento ${attempt + 1}/${maxRetries + 1})');
        await Future.delayed(retryDelay);
      }

      try {
        final settings = AppSettings();
        debugPrint('[HomeCubit] merchantId=${settings.merchantId}, productId=${settings.productId} (intento ${attempt + 1})');

        debugPrint('[HomeCubit] Llamando GetProductUseCase...');
        final product = await _getProduct(
          settings.merchantId,
          settings.productId,
        );
        debugPrint('[HomeCubit] Producto obtenido OK: id=${product.id}, nombre="${product.name}", precio=${product.price}');

        debugPrint('[HomeCubit] Llamando GetMerchantInfoUseCase...');
        final merchant = await _getMerchant(settings.merchantId);
        debugPrint('[HomeCubit] Merchant obtenido OK: nombre="${merchant.name}"');

        return (product: product, merchantName: merchant.name);
      } catch (e) {
        if (attempt < maxRetries) {
          debugPrint('[HomeCubit] Intento ${attempt + 1} fallo: $e');
          continue; // Reintentar
        }
        rethrow; // Agotados los reintentos, propagar error
      }
    }

    // Nunca deberia llegar aqui
    throw Exception('Agotados todos los intentos de carga');
  }

  /// Muestra el video de atraccion (robot cerca de persona).
  ///
  /// El video es un asset local, asi que funciona incluso si el producto
  /// no ha cargado (status=error). Solo intenta recargar si esta en error.
  Future<void> showAttract() async {
    debugPrint('[HomeCubit] showAttract() llamado');
    _cancelInactivityTimer();

    emit(state.copyWith(displayMode: DisplayMode.attract));
    debugPrint('[HomeCubit] Estado emitido: displayMode=attract');

    // Si estaba en error, intentar recargar el producto en segundo plano
    if (state.status == HomeStatus.error) {
      debugPrint('[HomeCubit] showAttract() -> status=error, recargando producto en background...');
      await load();
    }
  }

  /// Muestra el producto y programa el timer de inactividad.
  ///
  /// Requiere que el producto este cargado (status=loaded).
  /// Si esta en error, intenta recargar primero.
  Future<void> showProduct() async {
    debugPrint('[HomeCubit] showProduct() llamado');
    _cancelInactivityTimer();

    if (state.status == HomeStatus.loaded) {
      emit(state.copyWith(displayMode: DisplayMode.product));
      debugPrint('[HomeCubit] Estado emitido: displayMode=product');
      _startInactivityTimer();
      return;
    }

    if (state.status == HomeStatus.error) {
      debugPrint('[HomeCubit] showProduct() -> status=error, recargando...');
      await load();
      if (state.status == HomeStatus.loaded) {
        emit(state.copyWith(displayMode: DisplayMode.product));
        debugPrint('[HomeCubit] Recarga OK -> displayMode=product');
        _startInactivityTimer();
      } else {
        debugPrint('[HomeCubit] Recarga fallo, no se puede mostrar producto');
      }
      return;
    }

    debugPrint('[HomeCubit] showProduct() ignorado: status=${state.status} (aun no esta listo)');
  }

  /// Vuelve a reposo / espera.
  ///
  /// Funciona siempre, incluso sin producto cargado.
  Future<void> showIdle() async {
    debugPrint('[HomeCubit] showIdle() llamado');
    _cancelInactivityTimer();

    emit(state.copyWith(displayMode: DisplayMode.idle));
    debugPrint('[HomeCubit] Estado emitido: displayMode=idle');

    // Si estaba en error, intentar recargar el producto en segundo plano
    if (state.status == HomeStatus.error) {
      debugPrint('[HomeCubit] showIdle() -> status=error, recargando producto en background...');
      await load();
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
