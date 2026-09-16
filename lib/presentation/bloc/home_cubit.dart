import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config/app_settings.dart';
import '../../core/services/product_cache.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/merchant.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/selected_topping.dart';
import '../../domain/entities/topping.dart';
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

  /// Contador para generar ids de linea de carrito unicos dentro de la
  /// sesion (se combina con un timestamp para evitar colisiones).
  int _lineIdCounter = 0;

  /// Tiempo de inactividad antes de volver a [DisplayMode.attract].
  Duration get _inactivityTimeout => Duration(
        seconds: AppSettings().customerSessionTimeoutSeconds,
      );

  HomeCubit({
    required GetProductsUseCase getProducts,
    required GetMerchantInfoUseCase getMerchant,
  })  : _getProducts = getProducts,
        _getMerchant = getMerchant,
        super(const HomeState()) {
    load();
  }

  String _newLineId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_lineIdCounter++}';

  // ─── Carrito: productos sin configuracion (flujo "+/-" simple) ────────────

  /// Indice de la linea sin toppings de [product] dentro de [lines], o -1
  /// si no esta en el carrito.
  int _unconfiguredLineIndex(List<CartItem> lines, Product product) {
    final key = HomeState.cartKey(product);
    return lines.indexWhere((line) =>
        HomeState.cartKey(line.product) == key && !line.hasCustomConfiguration);
  }

  void incrementProduct(Product product) {
    final lines = List<CartItem>.from(state.cartLines);
    final index = _unconfiguredLineIndex(lines, product);

    if (index >= 0) {
      final current = lines[index];
      if (current.quantity >= AppSettings().maxCartItemQuantity) {
        registerCartInteraction();
        return;
      }
      final nextQuantity = current.quantity + 1;
      lines[index] = current.copyWith(
        quantity: nextQuantity,
        totalPrice: current.unitPrice * nextQuantity,
      );
    } else {
      lines.add(CartItem.configured(
        id: _newLineId(),
        product: product,
        quantity: 1,
        selectedToppings: const [],
        extraQuantities: const {},
      ));
    }

    emit(state.copyWith(cartLines: List.unmodifiable(lines)));
    registerCartInteraction();
  }

  void decrementProduct(Product product) {
    final lines = List<CartItem>.from(state.cartLines);
    final index = _unconfiguredLineIndex(lines, product);
    if (index < 0) return;

    final current = lines[index];
    final nextQuantity = current.quantity - 1;
    if (nextQuantity <= 0) {
      lines.removeAt(index);
    } else {
      lines[index] = current.copyWith(
        quantity: nextQuantity,
        totalPrice: current.unitPrice * nextQuantity,
      );
    }

    emit(state.copyWith(cartLines: List.unmodifiable(lines)));
    registerCartInteraction();
  }

  // ─── Carrito: productos con toppings (flujo del modal de configuracion) ───

  /// Agrega una linea configurada al carrito. Si ya existe una linea del
  /// mismo producto con exactamente la misma configuracion (mismos
  /// toppings/extras elegidos), suma la cantidad a esa linea en vez de
  /// crear una nueva.
  void addConfiguredItem({
    required Product product,
    required List<SelectedTopping> selectedToppings,
    required Map<int, Map<int, int>> extraQuantities,
    required int quantity,
  }) {
    if (quantity <= 0) return;

    final newLine = CartItem.configured(
      id: _newLineId(),
      product: product,
      quantity: quantity,
      selectedToppings: selectedToppings,
      extraQuantities: extraQuantities,
    );

    final lines = List<CartItem>.from(state.cartLines);
    final matchIndex = lines.indexWhere((line) =>
        HomeState.cartKey(line.product) == HomeState.cartKey(product) &&
        line.configurationSignature == newLine.configurationSignature);

    if (matchIndex >= 0) {
      final existing = lines[matchIndex];
      final mergedQuantity = existing.quantity + quantity;
      lines[matchIndex] = existing.copyWith(
        quantity: mergedQuantity,
        totalPrice: existing.unitPrice * mergedQuantity,
      );
    } else {
      lines.add(newLine);
    }

    emit(state.copyWith(cartLines: List.unmodifiable(lines)));
    registerCartInteraction();
  }

  void incrementCartLine(String lineId) {
    final lines = List<CartItem>.from(state.cartLines);
    final index = lines.indexWhere((line) => line.id == lineId);
    if (index < 0) return;

    final current = lines[index];
    if (current.quantity >= AppSettings().maxCartItemQuantity) {
      registerCartInteraction();
      return;
    }
    final nextQuantity = current.quantity + 1;
    lines[index] = current.copyWith(
      quantity: nextQuantity,
      totalPrice: current.unitPrice * nextQuantity,
    );
    emit(state.copyWith(cartLines: List.unmodifiable(lines)));
    registerCartInteraction();
  }

  void decrementCartLine(String lineId) {
    final lines = List<CartItem>.from(state.cartLines);
    final index = lines.indexWhere((line) => line.id == lineId);
    if (index < 0) return;

    final current = lines[index];
    final nextQuantity = current.quantity - 1;
    if (nextQuantity <= 0) {
      lines.removeAt(index);
    } else {
      lines[index] = current.copyWith(
        quantity: nextQuantity,
        totalPrice: current.unitPrice * nextQuantity,
      );
    }
    emit(state.copyWith(cartLines: List.unmodifiable(lines)));
    registerCartInteraction();
  }

  void removeCartLine(String lineId) {
    final lines = List<CartItem>.from(state.cartLines)
      ..removeWhere((line) => line.id == lineId);
    emit(state.copyWith(cartLines: List.unmodifiable(lines)));
    registerCartInteraction();
  }

  void clearCart() {
    if (state.cartLines.isEmpty) return;
    emit(state.copyWith(cartLines: const []));
    registerCartInteraction();
  }

  /// Reinicia el timeout mientras el cliente interactua con el carrito.
  void registerCartInteraction() {
    if (state.displayMode != DisplayMode.product) return;
    _cancelInactivityTimer();
    _startInactivityTimer(_inactivityTimeout);
  }

  /// Pausa la sesion de la home mientras otra pantalla controla el flujo.
  void pauseCustomerSessionTimeout() {
    _cancelInactivityTimer();
    debugPrint('[HomeCubit] Timeout de sesion pausado');
  }

  /// Reanuda el timeout solo si el cliente regreso al catalogo.
  void resumeCustomerSessionTimeout() {
    if (isClosed || state.displayMode != DisplayMode.product) return;
    _cancelInactivityTimer();
    _startInactivityTimer(_inactivityTimeout);
    debugPrint('[HomeCubit] Timeout de sesion reanudado');
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
        cartLines: const [],
        products: filteredProducts,
        currentIndex: 0,
        merchantName: result.merchantName,
        merchantNames: result.merchantNames,
        merchantIds: result.merchantIds,
        merchantsById: result.merchantsById,
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

  Future<_HomeLoadResult> _loadWithRetry() async {
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
        final merchantsById = <int, Merchant>{};
        final errors = <String>[];

        for (var i = 0; i < results.length; i++) {
          final merchantId = merchantsToLoad[i];
          final result = results[i];

          if (result != null) {
            allProducts.addAll(result.products);
            merchantNames.add(result.merchant.name);
            loadedMerchantIds.add(merchantId);
            merchantsById[merchantId] = result.merchant;
            debugPrint(
                '[HomeCubit] Merchant $merchantId: ${result.products.length} productos cargados');
          } else {
            errors.add('Merchant $merchantId: fallo al cargar');
          }
        }

        if (loadedMerchantIds.isEmpty) {
          throw Exception(
              'No se pudieron cargar productos de ningun merchant.\n${errors.join('\n')}');
        }

        if (errors.isNotEmpty) {
          debugPrint(
              '[HomeCubit] [WARN] ${errors.length} merchants fallaron, pero se cargaron ${allProducts.length} productos de ${loadedMerchantIds.length} merchants');
        }

        // merchantName principal: combina los nombres de todos los merchants
        final primaryName = merchantNames.join(' | ');

        return _HomeLoadResult(
          products: allProducts,
          merchantName: primaryName,
          merchantNames: merchantNames,
          merchantIds: loadedMerchantIds,
          merchantsById: Map.unmodifiable(merchantsById),
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
  Future<_MerchantLoadResult?> _loadSingleMerchant(int merchantId) async {
    try {
      debugPrint('[HomeCubit] Cargando merchant $merchantId...');
      final products = await _getProducts(merchantId);
      final merchant = await _getMerchant(merchantId);
      debugPrint(
          '[HomeCubit] Merchant $merchantId OK: ${products.length} productos, nombre="${merchant.name}"');
      return _MerchantLoadResult(products: products, merchant: merchant);
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

    debugPrint('[HomeCubit] [POLL] Iniciando ciclo de polling...');
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
      final cartSync = _reconcileCart(freshProducts);
      final productsChanged =
          !_listsAreIdentical(currentProducts, freshProducts);
      final cartChanged = !_cartLinesAreEqual(state.cartLines, cartSync.lines);
      if (!productsChanged && !cartChanged) {
        // Sin cambios: actualizar timestamp pero no emitir estado
        debugPrint('[HomeCubit] [OK] Polling: sin cambios detectados');
        _lastPollTimestamp = DateTime.now();
        return;
      }

      // ── Hay cambios: loguear detalle de lo que cambió ──
      debugPrint(
          '[HomeCubit] [CHG] ──────────────────────────────────────────────');
      debugPrint('[HomeCubit] [CHG] POLLING: CAMBIOS DETECTADOS');
      debugPrint(
          '[HomeCubit] [CHG] Antes: ${currentProducts.length} productos → Ahora: ${freshProducts.length} productos');
      _logProductDiff(currentProducts, freshProducts);
      debugPrint(
          '[HomeCubit] [CHG] ──────────────────────────────────────────────');

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
              '[HomeCubit] [WARN] Producto activo "${previousProduct.name}" (ID: ${previousProduct.id}) ya no está visible. Índice reseteado a 0.');
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
        cartLines: List.unmodifiable(cartSync.lines),
        cartSyncMessage: cartSync.message,
        cartSyncRevision: cartSync.message == null
            ? state.cartSyncRevision
            : state.cartSyncRevision + 1,
        merchantName: result.merchantName,
        merchantNames: result.merchantNames,
        merchantIds: result.merchantIds,
        merchantsById: result.merchantsById,
        lastPolledAt: DateTime.now(),
      ));

      debugPrint(
          '[HomeCubit] [OK] Estado actualizado vía polling (${freshProducts.length} productos visibles, índice=$newIndex)');
    } catch (e, stack) {
      // Fallo silencioso: no interrumpir al usuario, solo loguear.
      debugPrint('[HomeCubit] [WARN] Polling falló (red caída?): $e');
      debugPrint('[HomeCubit] StackTrace: $stack');
      // El estado actual se mantiene intacto. NO actualizar _lastPollTimestamp.
    }
  }

  /// Reconcilia las lineas del carrito contra el catalogo fresco.
  ///
  /// - Si el producto base de una linea ya no existe, la linea se elimina.
  /// - Si el producto sigue existiendo, se recalcula el precio con los
  ///   datos frescos (precio base + subtoppings), y se quitan del
  ///   selection los subtoppings/grupos que ya no existan. No se
  ///   re-valida min/max: el mismo alcance que ya tenia la reconciliacion
  ///   de precio antes de esta funcionalidad.
  _CartSyncResult _reconcileCart(List<Product> freshProducts) {
    final freshByKey = {
      for (final product in freshProducts) HomeState.cartKey(product): product,
    };

    final keptLines = <CartItem>[];
    final removedNames = <String>[];
    final priceChangedNames = <String>[];

    for (final line in state.cartLines) {
      final freshProduct = freshByKey[HomeState.cartKey(line.product)];
      if (freshProduct == null) {
        removedNames.add(line.product.name);
        continue;
      }

      final prunedToppings =
          _pruneSelectedToppings(line.selectedToppings, freshProduct);
      final prunedExtras =
          _pruneExtraQuantities(line.extraQuantities, freshProduct);
      final freshUnitPrice = CartItem.unitPriceFor(
        product: freshProduct,
        selectedToppings: prunedToppings,
        extraQuantities: prunedExtras,
      );

      if (freshUnitPrice != line.unitPrice) {
        priceChangedNames.add(freshProduct.name);
      }

      keptLines.add(line.copyWith(
        product: freshProduct,
        selectedToppings: prunedToppings,
        extraQuantities: prunedExtras,
        unitPrice: freshUnitPrice,
        totalPrice: freshUnitPrice * line.quantity,
      ));
    }

    final messages = <String>[];
    if (removedNames.isNotEmpty) {
      final availability = removedNames.length == 1
          ? 'ya no está disponible y fue retirado'
          : 'ya no están disponibles y fueron retirados';
      messages.add('${removedNames.join(', ')} $availability del carrito.');
    }
    if (priceChangedNames.isNotEmpty) {
      messages.add(
        'Se actualizó el precio de ${priceChangedNames.join(', ')}. '
        'Revisa el nuevo total.',
      );
    }

    return _CartSyncResult(
      lines: keptLines,
      message: messages.isEmpty ? null : messages.join(' '),
    );
  }

  /// Quita de [selected] los grupos y subtoppings que ya no existan en
  /// [freshProduct], y actualiza cada [Topping]/[SubTopping] restante a su
  /// version fresca (por si cambio de precio).
  List<SelectedTopping> _pruneSelectedToppings(
    List<SelectedTopping> selected,
    Product freshProduct,
  ) {
    final result = <SelectedTopping>[];
    for (final selection in selected) {
      final freshTopping = freshProduct.toppingById(selection.topping.id);
      if (freshTopping == null) continue;

      final freshSubToppings = selection.selectedSubToppings
          .map((sub) => freshTopping.subToppingById(sub.id))
          .whereType<SubTopping>()
          .toList();
      if (freshSubToppings.isEmpty) continue;

      result.add(SelectedTopping(
        topping: freshTopping,
        selectedSubToppings: freshSubToppings,
      ));
    }
    return result;
  }

  /// Igual que [_pruneSelectedToppings] pero para el mapa de cantidades de
  /// grupos `increment`.
  Map<int, Map<int, int>> _pruneExtraQuantities(
    Map<int, Map<int, int>> extraQuantities,
    Product freshProduct,
  ) {
    final result = <int, Map<int, int>>{};
    extraQuantities.forEach((toppingId, subQuantities) {
      final freshTopping = freshProduct.toppingById(toppingId);
      if (freshTopping == null) return;

      final prunedSub = <int, int>{};
      subQuantities.forEach((subToppingId, qty) {
        if (freshTopping.subToppingById(subToppingId) != null) {
          prunedSub[subToppingId] = qty;
        }
      });
      if (prunedSub.isNotEmpty) result[toppingId] = prunedSub;
    });
    return result;
  }

  bool _cartLinesAreEqual(List<CartItem> a, List<CartItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      if (a[i].quantity != b[i].quantity) return false;
      if (a[i].totalPrice != b[i].totalPrice) return false;
      if (a[i].unitPrice != b[i].unitPrice) return false;
      if (a[i].selectedToppings.length != b[i].selectedToppings.length) {
        return false;
      }
    }
    return true;
  }

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

  /// Loguea los cambios entre dos listas de productos para debugging.
  void _logProductDiff(List<Product> oldList, List<Product> newList) {
    final oldIds = oldList.map((p) => p.id).toSet();
    final newIds = newList.map((p) => p.id).toSet();

    // Productos agregados
    final added = newIds.difference(oldIds);
    if (added.isNotEmpty) {
      final addedProducts = newList.where((p) => added.contains(p.id));
      for (final p in addedProducts) {
        debugPrint('[HomeCubit]   [ADD] NUEVO:  "${p.name}" (ID: ${p.id}, '
            'Bs ${p.price}, merchant ${p.merchantId})');
      }
    }

    // Productos eliminados/ocultados
    final removed = oldIds.difference(newIds);
    if (removed.isNotEmpty) {
      final removedProducts = oldList.where((p) => removed.contains(p.id));
      for (final p in removedProducts) {
        debugPrint('[HomeCubit]   [DEL] OCULTO: "${p.name}" (ID: ${p.id}, '
            'merchant ${p.merchantId})');
      }
    }

    // Productos modificados (mismo ID pero campos cambiaron)
    final kept = oldIds.intersection(newIds);
    for (final id in kept) {
      final old = oldList.firstWhere((p) => p.id == id);
      final fresh = newList.firstWhere((p) => p.id == id);
      final changes = <String>[];
      if (old.name != fresh.name) {
        changes.add('nombre: "${old.name}" → "${fresh.name}"');
      }
      if (old.price != fresh.price) {
        changes.add('precio: Bs ${old.price} → Bs ${fresh.price}');
      }
      if (old.description != fresh.description) changes.add('descripción');
      if (old.urlImage != fresh.urlImage) changes.add('imagen');
      if (old.oldPrice != fresh.oldPrice) changes.add('oldPrice');
      if (changes.isNotEmpty) {
        debugPrint('[HomeCubit]   [EDIT]  EDITADO: "${fresh.name}" (ID: $id, '
            'merchant ${fresh.merchantId}): ${changes.join(', ')}');
      }
    }
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
      cartLines: const [],
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

    emit(state.copyWith(
      displayMode: DisplayMode.idle,
      cartLines: const [],
    ));
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
        cartLines: const [],
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
          cartLines: const [],
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
    _inactivityTimer?.cancel();
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

class _HomeLoadResult {
  final List<Product> products;
  final String merchantName;
  final List<String> merchantNames;
  final List<int> merchantIds;
  final Map<int, Merchant> merchantsById;

  const _HomeLoadResult({
    required this.products,
    required this.merchantName,
    required this.merchantNames,
    required this.merchantIds,
    required this.merchantsById,
  });
}

class _MerchantLoadResult {
  final List<Product> products;
  final Merchant merchant;

  const _MerchantLoadResult({
    required this.products,
    required this.merchant,
  });
}

class _CartSyncResult {
  final List<CartItem> lines;
  final String? message;

  const _CartSyncResult({
    required this.lines,
    required this.message,
  });
}
