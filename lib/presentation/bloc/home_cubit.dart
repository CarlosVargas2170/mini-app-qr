import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/app_settings.dart';
import '../../core/services/product_cache.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_merchant_info.dart';
import '../../domain/usecases/get_products.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final GetProductsUseCase _getProducts;
  final GetMerchantInfoUseCase _getMerchant;

  Timer? _inactivityTimer;

  /// Tiempo de inactividad antes de volver a [DisplayMode.attract].
  static const _inactivityTimeout = Duration(seconds: 60);

  HomeCubit({
    required GetProductsUseCase getProducts,
    required GetMerchantInfoUseCase getMerchant,
  })  : _getProducts = getProducts,
        _getMerchant = getMerchant,
        super(const HomeState()) {
    load();
  }

  Future<void> load() async {
    emit(state.copyWith(status: HomeStatus.loading, errorMessage: null));
    debugPrint('[HomeCubit] load() iniciado');

    try {
      final result = await _loadWithRetry();

      // Log de productos obtenidos del backend (antes del filtro)
      final allIds = result.products.map((p) => '${p.id}').join(', ');
      debugPrint(
          '[HomeCubit] Productos obtenidos de la API: ${result.products.length} total');
      debugPrint('[HomeCubit] IDs productos API: [$allIds]');

      // Aplicar filtro de visibilidad antes de emitir el estado
      final settings = AppSettings();
      final filter = settings.filterConfig;
      final filteredProducts = result.products
          .where((p) => filter.isProductVisible(p.id, p.merchantId))
          .toList();

      debugPrint(
          '[HomeCubit] Filtro aplicado: ${result.products.length} total -> ${filteredProducts.length} visibles (modo: ${filter.filterMode})');

      // Log de IDs de productos visibles (después del filtro)
      final visibleIds = filteredProducts.map((p) => '${p.id}').join(', ');
      debugPrint('[HomeCubit] IDs productos visibles: [$visibleIds]');

      emit(state.copyWith(
        status: HomeStatus.loaded,
        displayMode: DisplayMode.attract,
        products: filteredProducts,
        currentIndex: 0,
        merchantName: result.merchantName,
        merchantNames: result.merchantNames,
        merchantIds: result.merchantIds,
      ));
      debugPrint(
          '[HomeCubit] Estado emitido: loaded + attract (${filteredProducts.length} productos de ${result.merchantIds.length} merchants)');
    } catch (e, stack) {
      debugPrint('[HomeCubit] load FAILED (incluyendo retry): $e');
      debugPrint('[HomeCubit] StackTrace: $stack');
      emit(state.copyWith(
        status: HomeStatus.error,
        errorMessage: 'No se pudieron cargar los productos.\n${e.toString()}',
      ));
    }
  }

  Future<
      ({
        List<Product> products,
        String merchantName,
        List<String> merchantNames,
        List<int> merchantIds
      })> _loadWithRetry() async {
    const maxRetries = 1;
    const retryDelay = Duration(seconds: 2);

    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      if (attempt > 0) {
        debugPrint(
            '[HomeCubit] Reintentando en ${retryDelay.inSeconds}s... (intento ${attempt + 1}/${maxRetries + 1})');
        await Future.delayed(retryDelay);
      }

      try {
        final settings = AppSettings();
        final merchantsToLoad = settings.merchantIds;
        debugPrint(
            '[HomeCubit] merchantIds=$merchantsToLoad (intento ${attempt + 1})');

        if (merchantsToLoad.isEmpty) {
          throw Exception('No hay merchants configurados');
        }

        // Cargar todos los merchants en paralelo
        debugPrint(
            '[HomeCubit] Cargando ${merchantsToLoad.length} merchants en paralelo...');
        final results = await Future.wait(
          merchantsToLoad.map((merchantId) => _loadSingleMerchant(merchantId)),
        );

        // Combinar resultados de todos los merchants
        final allProducts = <Product>[];
        final merchantNames = <String>[];
        final loadedMerchantIds = <int>[];
        final errors = <String>[];

        for (var i = 0; i < results.length; i++) {
          final merchantId = merchantsToLoad[i];
          final result = results[i];

          if (result != null) {
            allProducts.addAll(result.products);
            merchantNames.add(result.merchantName);
            loadedMerchantIds.add(merchantId);
            debugPrint(
                '[HomeCubit] Merchant $merchantId: ${result.products.length} productos cargados');
          } else {
            errors.add('Merchant $merchantId: fallo al cargar');
          }
        }

        if (allProducts.isEmpty) {
          throw Exception(
              'No se pudieron cargar productos de ningun merchant.\n${errors.join('\n')}');
        }

        if (errors.isNotEmpty) {
          debugPrint(
              '[HomeCubit] ⚠️ ${errors.length} merchants fallaron, pero se cargaron ${allProducts.length} productos de ${loadedMerchantIds.length} merchants');
        }

        // merchantName principal: combina los nombres de todos los merchants
        final primaryName = merchantNames.join(' | ');

        // Poblar cache global para que AppServer pueda leer los productos
        final cache = ProductCache();
        cache.allProducts = List.unmodifiable(allProducts);
        cache.merchantNames = List.unmodifiable(merchantNames);
        cache.loadedMerchantIds = List.unmodifiable(loadedMerchantIds);
        debugPrint(
            '[HomeCubit] ProductCache actualizado: ${allProducts.length} productos de ${loadedMerchantIds.length} merchants');

        return (
          products: allProducts,
          merchantName: primaryName,
          merchantNames: merchantNames,
          merchantIds: loadedMerchantIds,
        );
      } catch (e) {
        if (attempt < maxRetries) {
          debugPrint('[HomeCubit] Intento ${attempt + 1} fallo: $e');
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Agotados todos los intentos de carga');
  }

  /// Carga los productos e info de un solo merchant.
  /// Retorna null si falla (para manejo graceful de errores).
  Future<({List<Product> products, String merchantName})?> _loadSingleMerchant(
      int merchantId) async {
    try {
      debugPrint('[HomeCubit] Cargando merchant $merchantId...');
      final products = await _getProducts(merchantId);
      final merchant = await _getMerchant(merchantId);
      debugPrint(
          '[HomeCubit] Merchant $merchantId OK: ${products.length} productos, nombre="${merchant.name}"');
      return (products: products, merchantName: merchant.name);
    } catch (e) {
      debugPrint('[HomeCubit] Error cargando merchant $merchantId: $e');
      return null; // Falla gracefully: un merchant caido no detiene a los demas
    }
  }

  /// Actualiza el indice del producto seleccionado en el carrusel.
  /// Reinicia el timer de inactividad cada vez que el usuario hace swipe.
  void updateCurrentIndex(int index) {
    if (index != state.currentIndex) {
      emit(state.copyWith(currentIndex: index));
      _cancelInactivityTimer();
      _startInactivityTimer(_inactivityTimeout);
    }
  }

  /// Muestra el video de atraccion (robot cerca de persona).
  Future<void> showAttract() async {
    debugPrint('[HomeCubit] showAttract() llamado');
    _cancelInactivityTimer();

    emit(state.copyWith(displayMode: DisplayMode.attract));
    debugPrint('[HomeCubit] Estado emitido: displayMode=attract');

    if (state.status == HomeStatus.error) {
      debugPrint(
          '[HomeCubit] showAttract() -> status=error, recargando en background...');
      await load();
    }
  }

  /// Muestra el carrusel de productos y programa el timer de inactividad.
  Future<void> showProduct() async {
    return showProductWithTimeout(_inactivityTimeout);
  }

  /// Muestra el carrusel con un timeout de inactividad personalizado.
  Future<void> showProductWithTimeout(Duration timeout) async {
    debugPrint(
        '[HomeCubit] showProductWithTimeout(${timeout.inSeconds}s) llamado');
    _cancelInactivityTimer();

    if (state.status == HomeStatus.loaded) {
      emit(state.copyWith(displayMode: DisplayMode.product));
      debugPrint('[HomeCubit] Estado emitido: displayMode=product');
      _startInactivityTimer(timeout);
      return;
    }

    if (state.status == HomeStatus.error) {
      debugPrint(
          '[HomeCubit] showProductWithTimeout() -> status=error, recargando...');
      await load();
      if (state.status == HomeStatus.loaded) {
        emit(state.copyWith(displayMode: DisplayMode.product));
        debugPrint('[HomeCubit] Recarga OK -> displayMode=product');
        _startInactivityTimer(timeout);
      } else {
        debugPrint('[HomeCubit] Recarga fallo, no se puede mostrar productos');
      }
      return;
    }

    debugPrint(
        '[HomeCubit] showProductWithTimeout() ignorado: status=${state.status}');
  }

  /// Vuelve a reposo / espera.
  Future<void> showIdle() async {
    debugPrint('[HomeCubit] showIdle() llamado');
    _cancelInactivityTimer();

    emit(state.copyWith(displayMode: DisplayMode.idle));
    debugPrint('[HomeCubit] Estado emitido: displayMode=idle');

    if (state.status == HomeStatus.error) {
      debugPrint(
          '[HomeCubit] showIdle() -> status=error, recargando en background...');
      await load();
    }
  }

  /// Muestra el carrusel de productos y resetea el indice al primer elemento.
  /// Ideal para cuando se reproduce el audio "Quieres un cafe?".
  Future<void> showProductResetCarousel() async {
    final timeout = _inactivityTimeout;
    debugPrint(
        '[HomeCubit] showProductResetCarousel(${timeout.inSeconds}s) llamado');
    _cancelInactivityTimer();

    if (state.status == HomeStatus.loaded) {
      emit(state.copyWith(
        displayMode: DisplayMode.product,
        currentIndex: 0,
      ));
      debugPrint(
          '[HomeCubit] Estado emitido: displayMode=product + currentIndex=0');
      _startInactivityTimer(timeout);
      return;
    }

    if (state.status == HomeStatus.error) {
      debugPrint(
          '[HomeCubit] showProductResetCarousel() -> status=error, recargando...');
      await load();
      if (state.status == HomeStatus.loaded) {
        emit(state.copyWith(
          displayMode: DisplayMode.product,
          currentIndex: 0,
        ));
        debugPrint(
            '[HomeCubit] Recarga OK -> displayMode=product + currentIndex=0');
        _startInactivityTimer(timeout);
      } else {
        debugPrint('[HomeCubit] Recarga fallo, no se puede mostrar productos');
      }
      return;
    }

    debugPrint(
        '[HomeCubit] showProductResetCarousel() ignorado: status=${state.status}');
  }

  void _startInactivityTimer([Duration? timeout]) {
    final duration = timeout ?? _inactivityTimeout;
    debugPrint(
        '[HomeCubit] Timer de inactividad iniciado (${duration.inSeconds}s)');
    _inactivityTimer = Timer(duration, () {
      if (!isClosed) {
        debugPrint(
            '[HomeCubit] Timer de inactividad expirado -> volviendo a attract');
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
