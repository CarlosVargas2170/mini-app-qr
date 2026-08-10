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

  /// Timestamp del último poll exitoso.
  /// Se usa para evitar polls demasiado frecuentes (umbral configurable).
  DateTime? _lastPollTimestamp;

  /// Tiempo de inactividad antes de volver a [DisplayMode.attract].
  static const _inactivityTimeout = Duration(seconds: 300);

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

      // Poblar cache global para que AppServer pueda leer los productos
      final cache = ProductCache();
      cache.allProducts = List.unmodifiable(result.products);
      cache.merchantNames = List.unmodifiable(result.merchantNames);
      cache.loadedMerchantIds = List.unmodifiable(result.merchantIds);
      debugPrint(
          '[HomeCubit] ProductCache actualizado: ${result.products.length} productos de ${result.merchantIds.length} merchants');

      // Aplicar filtro de visibilidad antes de emitir el estado
      final settings = AppSettings();
      final filter = settings.filterConfig;
      final filteredProducts = result.products
          .where((p) => filter.isProductVisible(p.id, p.merchantId))
          .toList();

      debugPrint(
          '[HomeCubit] Filtro aplicado: ${result.products.length} total -> ${filteredProducts.length} visibles (modo: ${filter.filterMode})');

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

      // Marcar timestamp del último poll exitoso.
      _lastPollTimestamp = DateTime.now();
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

  // ─── Polling on-demand ─────────────────────────────────────────────────────

  /// Verifica si los datos están stale y ejecuta un poll si es necesario.
  ///
  /// Se llama cada vez que se va a mostrar el carrusel de productos.
  /// Si el último poll fue hace menos de [AppSettings.productPollingStaleSeconds]
  /// segundos, omite el poll y usa los datos actuales.
  Future<void> _pollIfStale() async {
    final staleSeconds = AppSettings().productPollingStaleSeconds;
    if (staleSeconds <= 0) {
      debugPrint(
          '[HomeCubit] Polling on-demand DESHABILITADO (stale=$staleSeconds)');
      return;
    }

    final staleThreshold = Duration(seconds: staleSeconds);

    if (_lastPollTimestamp == null) {
      // Nunca se ha hecho poll (ej: primer showProduct tras load fallido)
      debugPrint('[HomeCubit] Sin timestamp previo → forzando poll');
      await _pollProducts();
      return;
    }

    final elapsed = DateTime.now().difference(_lastPollTimestamp!);
    if (elapsed >= staleThreshold) {
      debugPrint(
          '[HomeCubit] Datos stale (${elapsed.inSeconds}s >= ${staleSeconds}s) → ejecutando poll');
      await _pollProducts();
    } else {
      debugPrint(
          '[HomeCubit] Datos frescos (${elapsed.inSeconds}s < ${staleSeconds}s) → omitiendo poll');
    }
  }

  /// Fuerza un poll incondicional (ignora el umbral de staleness).
  ///
  /// Útil para comandos de recarga manual (remote-control, /products/reload).
  Future<void> forcePoll() async {
    debugPrint('[HomeCubit] forcePoll() → forzando poll incondicional');
    _lastPollTimestamp = null; // Anular timestamp para forzar
    await _pollProducts();
  }

  /// Ejecuta un ciclo de polling: obtiene productos frescos de la API
  /// y actualiza el estado silenciosamente si hay cambios.
  ///
  /// No interrumpe al usuario:
  /// - Mantiene el [displayMode] actual.
  /// - Recalcula [currentIndex] si el producto activo sigue existiendo.
  /// - Resetea [currentIndex] a 0 si el producto activo fue eliminado.
  /// - Si no hay cambios, no emite estado (ahorra rebuilds).
  Future<void> _pollProducts() async {
    if (isClosed) return;

    debugPrint('[HomeCubit] 🔄 Iniciando ciclo de polling...');
    try {
      final result = await _loadWithRetry();

      // Aplicar filtro de visibilidad
      final settings = AppSettings();
      final filter = settings.filterConfig;
      final freshProducts = result.products
          .where((p) => filter.isProductVisible(p.id, p.merchantId))
          .toList();

      // Comparar con los productos actuales para detectar cambios
      final currentProducts = state.products;
      if (_listsAreIdentical(currentProducts, freshProducts)) {
        // Sin cambios: actualizar timestamp pero no emitir estado
        debugPrint('[HomeCubit] ✅ Polling: sin cambios detectados');
        _lastPollTimestamp = DateTime.now();
        return;
      }

      // ── Hay cambios: actualizar cache y recalcular currentIndex ──
      debugPrint(
          '[HomeCubit] 🔃 Polling: cambios detectados (${currentProducts.length} → ${freshProducts.length} productos)');

      // Actualizar cache global con los productos frescos
      final cache = ProductCache();
      cache.allProducts = List.unmodifiable(result.products);
      cache.merchantNames = List.unmodifiable(result.merchantNames);
      cache.loadedMerchantIds = List.unmodifiable(result.merchantIds);
      debugPrint(
          '[HomeCubit] ProductCache actualizado: ${result.products.length} productos de ${result.merchantIds.length} merchants');

      var newIndex = 0;
      final previousProduct = state.currentProduct;
      if (previousProduct != null) {
        // Buscar el producto anterior en la nueva lista por ID
        final foundIndex =
            freshProducts.indexWhere((p) => p.id == previousProduct.id);
        newIndex = foundIndex >= 0 ? foundIndex : 0;
        if (foundIndex < 0) {
          debugPrint(
              '[HomeCubit] ⚠️ Producto activo "${previousProduct.name}" (ID: ${previousProduct.id}) ya no está visible. Índice reseteado a 0.');
        } else if (foundIndex != state.currentIndex) {
          debugPrint(
              '[HomeCubit] Producto activo "${previousProduct.name}" movido de índice ${state.currentIndex} → $foundIndex.');
        }
      }

      // Marcar timestamp del poll exitoso
      _lastPollTimestamp = DateTime.now();

      // Emitir nuevo estado sin cambiar displayMode
      emit(state.copyWith(
        status: HomeStatus.loaded,
        products: freshProducts,
        currentIndex: newIndex,
        merchantName: result.merchantName,
        merchantNames: result.merchantNames,
        merchantIds: result.merchantIds,
        lastPolledAt: DateTime.now(),
      ));

      debugPrint(
          '[HomeCubit] ✅ Estado actualizado vía polling (${freshProducts.length} productos visibles, índice=$newIndex)');
    } catch (e, stack) {
      // Fallo silencioso: no interrumpir al usuario, solo loguear.
      debugPrint('[HomeCubit] ⚠️ Polling falló (red caída?): $e');
      debugPrint('[HomeCubit] StackTrace: $stack');
      // El estado actual se mantiene intacto. NO actualizar _lastPollTimestamp.
    }
  }

  /// Compara dos listas de productos para determinar si son idénticas.
  ///
  /// Compara: orden, IDs, y campos relevantes (nombre, precio, oldPrice,
  /// descripción, urlImage, merchantId).
  bool _listsAreIdentical(List<Product> a, List<Product> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].name != b[i].name) return false;
      if (a[i].price != b[i].price) return false;
      if (a[i].oldPrice != b[i].oldPrice) return false;
      if (a[i].description != b[i].description) return false;
      if (a[i].urlImage != b[i].urlImage) return false;
      if (a[i].merchantId != b[i].merchantId) return false;
    }
    return true;
  }

  // ─── Fin polling ───────────────────────────────────────────────────────────

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
  ///
  /// Si [gifAsset] es provisto, actualiza el GIF mostrado.
  /// Si es null, mantiene el GIF actual configurado en el estado.
  Future<void> showAttract({String? gifAsset}) async {
    debugPrint('[HomeCubit] showAttract(gifAsset: $gifAsset) llamado');
    _cancelInactivityTimer();

    emit(state.copyWith(
      displayMode: DisplayMode.attract,
      attractGifAsset: gifAsset ?? state.attractGifAsset,
    ));
    debugPrint(
        '[HomeCubit] Estado emitido: displayMode=attract, gif=${gifAsset ?? state.attractGifAsset}');

    if (state.status == HomeStatus.error) {
      debugPrint(
          '[HomeCubit] showAttract() -> status=error, recargando en background...');
      await load();
    }
  }

  /// Cambia el GIF de atraccion y forza el modo attract inmediatamente.
  ///
  /// [assetPath] debe ser una ruta de asset valida (ej: `assets/images/coffee.gif`).
  /// Si es null, se usa el GIF por defecto (`assets/images/normal.gif`).
  Future<void> setAttractGif(String? assetPath) async {
    final gif = assetPath ?? 'assets/images/normal.gif';
    debugPrint('[HomeCubit] setAttractGif($gif) llamado');
    await showAttract(gifAsset: gif);
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

    // Verificar staleness antes de mostrar productos
    await _pollIfStale();

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

    // Verificar staleness antes de mostrar productos
    await _pollIfStale();

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
