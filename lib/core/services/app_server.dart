import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config/app_settings.dart';
import '../config/config_storage.dart';
import 'audio_service.dart';
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
/// --- Robot / UI ---
/// - `POST /proximity/near` -> Muestra video de atraccion
/// - `POST /greet`          -> Muestra producto + reproduce saludo
/// - `POST /product`        -> Muestra solo el producto
/// - `POST /proximity/away` -> Vuelve a reposo
/// --- Config ---
/// - `GET  /config`         -> Lee configuracion actual
/// - `POST /config`         -> Guarda nueva configuracion
class AppServer {
  HttpServer? _server;
  final int port;

  AppServer({this.port = 8080});

  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      if (kDebugMode) {
        debugPrint('[AppServer] Servidor iniciado en http://0.0.0.0:$port');
      }

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
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE, PATCH');
    response.headers.add('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization, X-Requested-With');
    response.headers.add('Access-Control-Max-Age', '86400'); // Cache preflight 24h

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

      final played = await AudioService.play(asset, volume: volume, force: force);
      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'asset': asset,
        'message': played ? 'Reproduciendo "$asset"' : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-question' && method == 'POST') {
      final played = await AudioService.playQuestion();
      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played ? 'Reproduciendo audio de pregunta' : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-thanks' && method == 'POST') {
      final played = await AudioService.playThanks();
      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played ? 'Reproduciendo audio de agradecimiento' : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-buy' && method == 'POST') {
      final played = await AudioService.playBuy();
      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played ? 'Reproduciendo audio de compra' : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-order' && method == 'POST') {
      final played = await AudioService.playThereIsAnOrder();
      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played ? 'Reproduciendo audio de orden recibida' : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-attention' && method == 'POST') {
      final played = await AudioService.playAttentionExcuseMe();
      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played ? 'Reproduciendo audio de atencion' : 'Cooldown activo, audio omitido',
      });
      return;
    }

    if (path == '/play-collect-tray' && method == 'POST') {
      final played = await AudioService.playCollectTray();
      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'message': played ? 'Reproduciendo audio de cobrar bandeja' : 'Cooldown activo, audio omitido',
      });
      return;
    }

    // --- Robot / Proximity endpoints ---
    if (path == '/proximity/near' && method == 'POST') {
      UiCommandBus.emit(UiCommand.showAttract);
      _sendJson(response, 200, {'success': true, 'mode': 'attract', 'message': 'Mostrando video de atraccion'});
      return;
    }

    if (path == '/greet' && method == 'POST') {
      UiCommandBus.emit(UiCommand.showProduct);
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
      UiCommandBus.emit(UiCommand.showProduct);
      _sendJson(response, 200, {'success': true, 'mode': 'product', 'audio': false, 'message': 'Mostrando solo el producto'});
      return;
    }

    if (path == '/proximity/away' && method == 'POST') {
      UiCommandBus.emit(UiCommand.showIdle);
      _sendJson(response, 200, {'success': true, 'mode': 'idle', 'message': 'Volviendo a reposo'});
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

    // --- 404 ---
    _sendJson(response, 404, {'success': false, 'message': 'Endpoint no encontrado'});
  }

  // -- Audio handlers --

  Future<void> _handlePlayAudio(HttpRequest request, HttpResponse response) async {
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

      final played = await AudioService.play(asset, volume: volume, force: force);
      _sendJson(response, 200, {
        'success': true,
        'played': played,
        'asset': asset,
        'message': played ? 'Reproduciendo "$asset"' : 'Cooldown activo, audio omitido',
      });
    } catch (e) {
      _sendJson(response, 400, {'success': false, 'message': 'Error reproduciendo audio: $e'});
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
        'merchantId': settings.merchantId,
        'productId': settings.productId,
      },
    });
  }

  Future<void> _handlePostConfig(HttpRequest request, HttpResponse response) async {
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
        settings.merchantId = (json['merchantId'] as num).toInt();
        updated['merchantId'] = true;
        needsReload = true; // Producto puede recargarse en caliente
      }
      if (json.containsKey('productId')) {
        settings.productId = (json['productId'] as num).toInt();
        updated['productId'] = true;
        needsReload = true; // Producto puede recargarse en caliente
      }

      await ConfigStorage.write({
        'baseUrl': settings.baseUrl,
        'bearerToken': settings.bearerToken,
        'merchantId': settings.merchantId,
        'productId': settings.productId,
      });

      // Recargar producto en caliente si cambio merchantId o productId
      if (needsReload) {
        debugPrint('[AppServer] Config cambio (merchant/product) -> emitiendo reloadProduct');
        UiCommandBus.emit(UiCommand.reloadProduct);
      }

      final messages = <String>[];
      if (needsReload) messages.add('Producto recargado en caliente.');
      if (needsRestart) messages.add('Reinicia la app para aplicar cambios de URL/Token.');
      if (messages.isEmpty) messages.add('Configuracion guardada.');

      _sendJson(response, 200, {
        'success': true,
        'message': messages.join(' '),
        'updated': updated.keys.toList(),
        'needsRestart': needsRestart,
        'needsReload': needsReload,
      });
    } catch (e) {
      _sendJson(response, 400, {'success': false, 'message': 'JSON invalido: $e'});
    }
  }

  // -- Helpers --

  void _sendJson(HttpResponse response, int statusCode, Map<String, dynamic> data) {
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
