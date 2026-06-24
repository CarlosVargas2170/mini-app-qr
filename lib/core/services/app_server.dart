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
/// - `GET  /play-question`  -> Reproduce audio
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

    // CORS
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
    response.headers.contentType = ContentType.json;

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      response.close();
      return;
    }

    final path = request.uri.path;
    final method = request.method;

    // --- Audio endpoints ---
    if (path == '/play-question' && method == 'GET') {
      AudioService.playQuestion();
      _sendJson(response, 200, {'success': true, 'message': 'Reproduciendo audio de pregunta'});
      return;
    }

    if (path == '/play-thanks' && method == 'GET') {
      AudioService.playThanks();
      _sendJson(response, 200, {'success': true, 'message': 'Reproduciendo audio de agradecimiento'});
      return;
    }

    // --- Robot / Proximity endpoints ---
    if (path == '/proximity/near' && method == 'GET') {
      UiCommandBus.emit(UiCommand.showAttract);
      _sendJson(response, 200, {'success': true, 'mode': 'attract', 'message': 'Mostrando video de atraccion'});
      return;
    }

    if (path == '/greet' && method == 'GET') {
      UiCommandBus.emit(UiCommand.showProduct);
      AudioService.playQuestion();
      _sendJson(response, 200, {'success': true, 'mode': 'product', 'audio': true, 'message': 'Mostrando producto y reproduciendo saludo'});
      return;
    }

    if (path == '/product' && method == 'GET') {
      UiCommandBus.emit(UiCommand.showProduct);
      _sendJson(response, 200, {'success': true, 'mode': 'product', 'audio': false, 'message': 'Mostrando solo el producto'});
      return;
    }

    if (path == '/proximity/away' && method == 'GET') {
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

      // Solo actualiza los campos que vienen en el body.
      if (json.containsKey('baseUrl')) {
        settings.baseUrl = json['baseUrl'] as String;
        updated['baseUrl'] = true;
      }
      if (json.containsKey('bearerToken')) {
        settings.bearerToken = json['bearerToken'] as String;
        updated['bearerToken'] = true;
      }
      if (json.containsKey('merchantId')) {
        settings.merchantId = (json['merchantId'] as num).toInt();
        updated['merchantId'] = true;
      }
      if (json.containsKey('productId')) {
        settings.productId = (json['productId'] as num).toInt();
        updated['productId'] = true;
      }

      await ConfigStorage.write({
        'baseUrl': settings.baseUrl,
        'bearerToken': settings.bearerToken,
        'merchantId': settings.merchantId,
        'productId': settings.productId,
      });

      _sendJson(response, 200, {
        'success': true,
        'message': 'Configuracion actualizada y guardada. Reinicia la app para aplicar los cambios.',
        'updated': updated.keys.toList(),
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
