import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/app_settings.dart';
import '../config/config_storage.dart';
import 'audio_service.dart';
import 'payment_counter.dart';
import 'payment_polling_status.dart';
import 'product_cache.dart';
import 'ui_command_bus.dart';

/// Servidor HTTP unificado de la aplicacion.
///
/// Expone todos los endpoints de la app en un solo puerto:
/// --- Audio ---
/// - `POST /audio/play`     -> Reproduce cualquier asset de audio (body: {"asset": "audio/foo.wav"})
/// - `POST /audio/stop`     -> Detiene el audio actual
/// - `POST /play-audio`     -> Reproduce audio por query param (ej: ?asset=audio/foo.wav&volume=1.0)
/// - `POST /play-question`  -> Reproduce audio de pregunta (legacy)
/// - `POST /play-thanks`    -> Reproduce audio de agradecimiento (legacy)
/// - `POST /play-buy`       -> Reproduce audio de compra (legacy)
/// - `POST /play-order`     -> Reproduce audio de orden recibida
/// - `POST /play-attention` -> Reproduce audio de atencion / disculpa
/// - `POST /play-collect-tray` -> Reproduce audio de cobrar bandeja
/// - `POST /play-coffee`       -> Reproduce audio "aqui esta tu cafe"
/// --- Robot / UI ---
/// - `POST /proximity/near` -> Muestra video de atraccion
/// - `POST /greet`          -> Muestra producto + reproduce saludo
/// - `POST /product`        -> Muestra solo el producto
/// - `POST /proximity/away` -> Vuelve a reposo
/// - `POST /carrusel/product` -> Idéntico a /proximity/near
/// --- Attract GIF ---
/// - `POST /attract/set`    -> Cambia el GIF de atraccion (body: {"gif": "nombre"})
/// - `GET  /attract/current` -> Devuelve el nombre del GIF actual
/// --- Pago QR (home) ---
/// - `POST /payment/start-polling` -> Activa polling del QR visible en home
/// - `POST /payment/stop-polling`  -> Detiene polling sin cancelar la orden
/// - `GET  /payment/polling-status` -> Estado actual del polling (remote-control)
/// --- Config ---
/// - `GET  /config`         -> Lee configuracion actual
/// - `POST /config`         -> Guarda nueva configuracion
class AppServer {
  HttpServer? _server;
  final int port;
  // AppServer({this.port = 8080});
  AppServer({this.port = 5050});

  Future<void> start() async {
    try {
      final host = AppSettings().baseUrlVpn;
      debugPrint('[AppServer] Iniciando servidor en $host:$port ...');
      final addr = InternetAddress.tryParse(host) ?? InternetAddress.anyIPv4;
      debugPrint('[AppServer] Resolviendo direccion: $addr');
      // _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server = await HttpServer.bind(addr, AppSettings().portVpn);
      debugPrint('[AppServer] Servidor iniciado en $_server');
      final actualPort = AppSettings().portVpn;
      debugPrint('[AppServer] Servidor iniciado en http://$addr:$actualPort');

      // if (kDebugMode) {
      //   debugPrint('[AppServer] Servidor iniciado en http://$addr:$actualPort');
      // }

      await for (final request in _server!) {
        _handleRequest(request);
      }
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint('[AppServer] No se pudo iniciar el servidor: $e');
      }
    }
  }

  void _handleRequest(HttpRequest request) async {
    final response = request.response;
    final path = request.uri.path;
    final method = request.method;

    // Log de todas las peticiones que llegan
    debugPrint('[AppServer] ${request.method} ${request.uri}');

    // CORS permisivo para funcionar con ngrok, navegadores, PWA, etc.
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods',
        'GET, POST, OPTIONS, PUT, DELETE, PATCH');
    response.headers.add('Access-Control-Allow-Headers',
        'Origin, Content-Type, Accept, Authorization, X-Requested-With');
    response.headers
        .add('Access-Control-Max-Age', '86400'); // Cache preflight 24h

    if (method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    response.headers.contentType = ContentType.json;

    // --- Audio endpoints ---
    if (path == '/audio/play' && method == 'POST') {
      await _handlePlayAudio(request, response);
      return;
    }

    if (path == '/audio/stop' && method == 'POST') {
      await AudioService.stop();
      _sendJson(response, 200, {'success': true, 'message': 'Audio detenido'});
      return;
    }

    // NUEVO: endpoint simple por query param (facil de probar desde navegador)
    if (path == '/play-audio' && method == 'POST') {
      final params = request.uri.queryParameters;
      final asset = params['asset'];
      final volume = double.tryParse(params['volume'] ?? '1.0') ?? 1.0;
      final force = params['force'] == 'true';

      if (asset == null || asset.isEmpty) {
        _sendJson(response, 400, {
          'success': false,
          'message': 'Falta parametro ?asset=audio/foo.wav',
        });
        return;
      }

      AudioService.setRemoteCall(true);

      // displayText opcional vía query param (?displayText=Hola)
      final displayText = params['displayText'];
      final played = await AudioService.play(
        asset,
        volume: volume,
        force: force,
        displayText: displayText,
      );

      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'asset': asset,
        'displayText': displayText,
        'message': played
            ? 'Reproduciendo "$asset"'
            : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-question' && method == 'POST') {
      UiCommandBus.emit(const ShowProductResetCarousel());

      AudioService.setRemoteCall(true);
      final played = await AudioService.playQuestion();

      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played
            ? 'Reproduciendo audio de pregunta + mostrando producto'
            : 'Mostrando producto (audio omitido por cooldown)',
      });
      return;
    }

    if (path == '/play-thanks' && method == 'POST') {
      AudioService.setRemoteCall(true);
      final played = await AudioService.playThanks();

      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played
            ? 'Reproduciendo audio de agradecimiento'
            : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-buy' && method == 'POST') {
      AudioService.setRemoteCall(true);
      final played = await AudioService.playBuy();

      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played
            ? 'Reproduciendo audio de compra'
            : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-order' && method == 'POST') {
      AudioService.setRemoteCall(true);
      final played = await AudioService.playThereIsAnOrder();

      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played
            ? 'Reproduciendo audio de orden recibida'
            : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-attention' && method == 'POST') {
      AudioService.setRemoteCall(true);
      final played = await AudioService.playAttentionExcuseMe();

      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played
            ? 'Reproduciendo audio de atencion'
            : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-collect-tray' && method == 'POST') {
      AudioService.setRemoteCall(true);
      final played = await AudioService.playCollectTray();

      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played
            ? 'Reproduciendo audio de cobrar bandeja'
            : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-coffee' && method == 'POST') {
      AudioService.setRemoteCall(true);
      final played = await AudioService.playHereIsCoffee();

      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played
            ? 'Reproduciendo audio aqui esta tu cafe'
            : 'Cooldown activo, audio omitido',
      });
      return;
    }

    // --- Robot / Proximity endpoints ---
    if (path == '/proximity/near' && method == 'POST') {
      UiCommandBus.emit(const ShowAttract());
      _sendJson(response, 200, {
        'success': true,
        'mode': 'attract',
        'message': 'Mostrando video de atraccion'
      });
      return;
    }

    if (path == '/greet' && method == 'POST') {
      UiCommandBus.emit(const ShowProductResetCarousel());

      AudioService.setRemoteCall(true);
      final played = await AudioService.playQuestion();

      _sendJson(response, 200, {
        'success': true,
        'mode': 'product',
        'audio': played,
        'message': played
            ? 'Mostrando producto y reproduciendo saludo'
            : 'Mostrando producto (audio omitido por cooldown)',
      });
      return;
    }

    if (path == '/product' && method == 'POST') {
      UiCommandBus.emit(const ShowProduct());
      _sendJson(response, 200, {
        'success': true,
        'mode': 'product',
        'audio': false,
        'message': 'Mostrando solo el producto'
      });
      return;
    }

    if (path == '/cancel-payment' && method == 'POST') {
      UiCommandBus.emit(const CancelPayment());
      _sendJson(response, 200, {
        'success': true,
        'message': 'Pago cancelado, volviendo al producto'
      });
      return;
    }

    // --- Payment polling (manual, operador) ---
    if (path == '/payment/start-polling' && method == 'POST') {
      UiCommandBus.emit(const StartPaymentPolling());
      _sendJson(response, 200, {
        'success': true,
        'message': 'Polling de pago activado en el producto visible de la home',
      });
      return;
    }

    if (path == '/payment/stop-polling' && method == 'POST') {
      UiCommandBus.emit(const StopPaymentPolling());
      _sendJson(response, 200, {
        'success': true,
        'message': 'Polling de pago detenido',
      });
      return;
    }

    if (path == '/payment/polling-status' && method == 'GET') {
      _sendJson(response, 200, PaymentPollingStatus().toJson());
      return;
    }

    if (path == '/payment/reset-counter' && method == 'POST') {
      PaymentCounter().reset();
      _sendJson(response, 200, {
        'success': true,
        'message': 'Contador de ventas reiniciado',
        'counter': PaymentCounter().toJson(),
      });
      return;
    }

    if (path == '/proximity/away' && method == 'POST') {
      UiCommandBus.emit(const ShowIdle());
      _sendJson(response, 200,
          {'success': true, 'mode': 'idle', 'message': 'Volviendo a reposo'});
      return;
    }

    if (path == '/carrusel/product' && method == 'POST') {
      UiCommandBus.emit(const ShowAttract());
      _sendJson(response, 200, {
        'success': true,
        'mode': 'attract',
        'message': 'Mostrando video de atraccion'
      });
      return;
    }

    // --- Config endpoints ---
    if (path == '/config') {
      if (method == 'GET') {
        await _handleGetConfig(response);
        return;
      }
      if (method == 'POST') {
        await _handlePostConfig(request, response);
        return;
      }
    }

    // --- Product filter endpoints ---
    if (path == '/products' && method == 'GET') {
      await _handleGetProducts(response);
      return;
    }

    if (path == '/products/filter' && method == 'POST') {
      await _handlePostProductsFilter(request, response);
      return;
    }

    if (path == '/products/reload' && method == 'POST') {
      await _handlePostProductsReload(response);
      return;
    }

    // --- Product polling endpoints ---
    if (path == '/products/polling/force' && method == 'POST') {
      await _handleForceProductPoll(response);
      return;
    }

    if (path == '/products/polling/status' && method == 'GET') {
      await _handleGetProductPollingStatus(response);
      return;
    }

    // --- Attract GIF endpoints ---
    if (path == '/attract/set' && method == 'POST') {
      await _handleSetAttractGif(request, response);
      return;
    }

    if (path == '/attract/current' && method == 'GET') {
      final gifName = UiCommandBus.currentGifName;
      _sendJson(response, 200, {
        'success': true,
        'gif': gifName,
        'assetPath': 'assets/images/$gifName.gif',
      });
      return;
    }

    // --- 404 ---
    _sendJson(
        response, 404, {'success': false, 'message': 'Endpoint no encontrado'});
  }

  // -- Audio handlers --

  Future<void> _handlePlayAudio(
      HttpRequest request, HttpResponse response) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final asset = json['asset'] as String?;
      if (asset == null || asset.isEmpty) {
        _sendJson(response, 400, {
          'success': false,
          'message': 'Body debe contener "asset" con la ruta del audio',
        });
        return;
      }

      final volume = (json['volume'] as num?)?.toDouble() ?? 1.0;
      final force = json['force'] == true;

      AudioService.setRemoteCall(true);

      final showOverlay = json['showOverlay'] ?? true;

      // displayText opcional: el remote-control puede enviar el texto a mostrar.
      final displayText = json['displayText'] as String?;
      final played = await AudioService.play(
        asset,
        volume: volume,
        force: force,
        displayText: displayText,
        showOverlay: showOverlay,
      );

      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'asset': asset,
        'displayText': displayText,
        'message': played
            ? 'Reproduciendo "$asset"'
            : 'Cooldown activo, audio omitido',
      });
    } catch (e) {
      _sendJson(response, 400,
          {'success': false, 'message': 'Error reproduciendo audio: $e'});
    }
  }

  // -- Config handlers --

  Future<void> _handleGetConfig(HttpResponse response) async {
    final settings = AppSettings();
    _sendJson(response, 200, {
      'success': true,
      'data': {
        'baseUrl': settings.baseUrl,
        'bearerToken': settings.bearerToken,
        'merchantId': settings.merchantId, // Compatibilidad: primer merchant
        'merchantIds': settings.merchantIds, // Nuevo: lista completa
        'productId': settings.productId,
        'baseUrlVpn': settings.baseUrlVpn,
        'portVpn': settings.portVpn,
      },
    });
  }

  Future<void> _handlePostConfig(
      HttpRequest request, HttpResponse response) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (json.isEmpty) {
        _sendJson(response, 400, {
          'success': false,
          'message': 'El body no puede estar vacio',
        });
        return;
      }

      final settings = AppSettings();
      final updated = <String, dynamic>{};
      var needsReload = false;
      var needsRestart = false;

      // Solo actualiza los campos que vienen en el body.
      if (json.containsKey('baseUrl')) {
        settings.baseUrl = json['baseUrl'] as String;
        updated['baseUrl'] = true;
        needsRestart = true; // Dio se crea en ServiceLocator.init()
      }
      if (json.containsKey('bearerToken')) {
        settings.bearerToken = json['bearerToken'] as String;
        updated['bearerToken'] = true;
        needsRestart = true; // Dio se crea en ServiceLocator.init()
      }
      if (json.containsKey('merchantId')) {
        // Compatibilidad: merchantId (valor único) se convierte a merchantIds (lista)
        settings.merchantIds = [(json['merchantId'] as num).toInt()];
        updated['merchantId'] = true;
        needsReload = true; // Producto puede recargarse en caliente
      }
      if (json.containsKey('merchantIds')) {
        // Nuevo formato: lista de merchantIds
        final merchantIdsJson = json['merchantIds'];
        if (merchantIdsJson is List) {
          settings.merchantIds =
              merchantIdsJson.map((e) => (e as num).toInt()).toList();
          updated['merchantIds'] = true;
          needsReload = true; // Producto puede recargarse en caliente
        }
      }
      if (json.containsKey('productId')) {
        settings.productId = (json['productId'] as num).toInt();
        updated['productId'] = true;
        needsReload = true; // Producto puede recargarse en caliente
      }

      if (json.containsKey('baseUrlVpn')) {
        settings.baseUrlVpn = json['baseUrlVpn'] as String;
        updated['baseUrlVpn'] = true;
        needsRestart = true; // Cambiar URL del servidor requiere reinicio
      }
      if (json.containsKey('portVpn')) {
        settings.portVpn = (json['portVpn'] as num).toInt();
        updated['portVpn'] = true;
        needsRestart = true; // Cambiar puerto del servidor requiere reinicio
      }

      // La configuracion de conexion se toma del archivo .env.
      // No se persiste en disco.

      // Recargar producto en caliente si cambio merchantId o productId
      if (needsReload) {
        debugPrint(
            '[AppServer] Config cambio (merchant/product) -> emitiendo reloadProduct');
        UiCommandBus.emit(const ReloadProduct());
      }

      final messages = <String>[];
      if (needsReload) messages.add('Producto recargado en caliente.');
      if (needsRestart)
        messages.add('Reinicia la app para aplicar cambios de URL/Token.');
      if (messages.isEmpty) messages.add('Configuracion guardada.');

      _sendJson(response, 200, {
        'success': true,
        'message': messages.join(' '),
        'updated': updated.keys.toList(),
        'needsRestart': needsRestart,
        'needsReload': needsReload,
      });
    } catch (e) {
      _sendJson(
          response, 400, {'success': false, 'message': 'JSON invalido: $e'});
    }
  }

  // -- Helpers --

  // -- Product filter handlers --

  /// GET /products — Retorna todos los productos cargados, agrupados por merchant,
  /// con su estado de visibilidad segun la configuracion de filtros.
  Future<void> _handleGetProducts(HttpResponse response) async {
    final cache = ProductCache();
    final settings = AppSettings();

    if (!cache.isLoaded) {
      _sendJson(response, 200, {
        'success': true,
        'data': null,
        'cacheLoaded': false,
        'message': 'Productos aun no cargados. Espera a que la app inicie.',
      });
      return;
    }

    _sendJson(response, 200, {
      'success': true,
      'data': cache.buildProductsResponse(settings.filterConfig),
      'cacheLoaded': true,
    });
  }

  /// POST /products/filter — Actualiza la configuracion de filtros de productos.
  ///
  /// Body esperado:
  /// ```json
  /// {
  ///   "merchants": { "53": { "enabled": true }, "54": { "enabled": false } },
  ///   "products": { "457969": { "visible": false }, "457970": { "visible": true, "pinned": true } },
  ///   "filterMode": "blacklist",
  ///   "reload": true
  /// }
  /// ```
  Future<void> _handlePostProductsFilter(
      HttpRequest request, HttpResponse response) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final settings = AppSettings();
      final filter = settings.filterConfig;
      final changes = <String>[];

      // Actualizar merchants
      if (json['merchants'] is Map) {
        final merchants = json['merchants'] as Map<String, dynamic>;
        for (final entry in merchants.entries) {
          final merchantId = int.tryParse(entry.key) ?? 0;
          final data = entry.value as Map<String, dynamic>?;
          if (data == null) continue;

          if (data.containsKey('enabled')) {
            final enabled = data['enabled'] == true;
            if (enabled) {
              filter.enabledMerchants.add(merchantId);
            } else {
              filter.enabledMerchants.remove(merchantId);
            }
            changes.add(
                'Merchant $merchantId: ${enabled ? "habilitado" : "deshabilitado"}');
          }
        }
      }

      // Actualizar productos
      if (json['products'] is Map) {
        final products = json['products'] as Map<String, dynamic>;
        for (final entry in products.entries) {
          final productId = int.tryParse(entry.key) ?? 0;
          final data = entry.value as Map<String, dynamic>?;
          if (data == null) continue;

          if (data.containsKey('visible')) {
            final visible = data['visible'] == true;
            if (visible) {
              filter.hiddenProducts.remove(productId);
            } else {
              filter.hiddenProducts.add(productId);
            }
            changes
                .add('Producto $productId: ${visible ? "visible" : "oculto"}');
          }

          if (data.containsKey('pinned')) {
            final pinned = data['pinned'] == true;
            if (pinned) {
              filter.pinnedProducts.add(productId);
              filter.hiddenProducts
                  .remove(productId); // Pinned no puede estar oculto
            } else {
              filter.pinnedProducts.remove(productId);
            }
            changes
                .add('Producto $productId: ${pinned ? "fijado" : "desfijado"}');
          }
        }
      }

      // Actualizar modo de filtro
      if (json['filterMode'] is String) {
        final mode = json['filterMode'] as String;
        if (['all', 'blacklist', 'whitelist'].contains(mode)) {
          filter.filterMode = mode;
          changes.add('Modo de filtro: $mode');
        }
      }

      // Resetear si se pide
      if (json['reset'] == true) {
        filter.reset();
        changes.add('Filtros reseteados');
      }

      // Los filtros viven solo en memoria (no se persisten en disco).
      // Al reiniciar la app, todos los productos vuelven a ser visibles.

      final reload = json['reload'] == true;
      if (reload) {
        debugPrint(
            '[AppServer] Filtros actualizados -> emitiendo reloadProduct');
        UiCommandBus.emit(const ReloadProduct());
      }

      _sendJson(response, 200, {
        'success': true,
        'message': changes.isEmpty ? 'Sin cambios' : changes.join('; '),
        'changes': changes,
        'filterMode': filter.filterMode,
        'reloaded': reload,
      });
    } catch (e) {
      _sendJson(
          response, 400, {'success': false, 'message': 'JSON invalido: $e'});
    }
  }

  /// POST /products/reload — Fuerza la recarga de productos desde la API.
  Future<void> _handlePostProductsReload(HttpResponse response) async {
    debugPrint('[AppServer] Recarga de productos solicitada');
    UiCommandBus.emit(const ReloadProduct());
    _sendJson(response, 200, {
      'success': true,
      'message':
          'Recarga de productos disparada. Los productos se actualizaran en breve.',
    });
  }

  /// POST /products/polling/force — Fuerza un poll incondicional de productos.
  Future<void> _handleForceProductPoll(HttpResponse response) async {
    debugPrint('[AppServer] Forzando poll de productos');
    UiCommandBus.emit(const ForceProductPoll());
    _sendJson(response, 200, {
      'success': true,
      'message': 'Poll de productos forzado.',
    });
  }

  /// GET /products/polling/status — Retorna la configuración de staleness.
  Future<void> _handleGetProductPollingStatus(HttpResponse response) async {
    final settings = AppSettings();
    _sendJson(response, 200, {
      'success': true,
      'data': {
        'staleSeconds': settings.productPollingStaleSeconds,
      },
    });
  }

  /// POST /attract/set — Cambia el GIF de atraccion y lo muestra inmediatamente.
  ///
  /// Body esperado:
  /// ```json
  /// { "gif": "attract" }
  /// ```
  ///
  /// El nombre se mapea a `assets/images/{gif}.gif`.
  /// Si no se envia, se usa `"attract"` por defecto.
  Future<void> _handleSetAttractGif(
      HttpRequest request, HttpResponse response) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      print('[AppServer] Cambio de GIF de atraccion solicitado: $json');
      final gifName = json['gif'] as String? ?? 'attract';
      final assetPath = 'assets/images/$gifName.gif';
      print('[AppServer] Cambiando GIF de atraccion a: $gifName ($assetPath)');
      UiCommandBus.currentGifName = gifName;
      UiCommandBus.emit(ShowAttract(gifAsset: assetPath));

      _sendJson(response, 200, {
        'success': true,
        'gif': gifName,
        'assetPath': assetPath,
        'message': 'GIF cambiado a "$gifName" y mostrando atraccion',
      });
    } catch (e) {
      _sendJson(
          response, 400, {'success': false, 'message': 'JSON invalido: $e'});
    }
  }

  // -- JSON helper --

  void _sendJson(
      HttpResponse response, int statusCode, Map<String, dynamic> data) {
    response.statusCode = statusCode;
    response.write(jsonEncode(data));
    response.close();
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    if (kDebugMode) debugPrint('[AppServer] Servidor detenido.');
  }
}
