import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'audio_service.dart';

/// Servidor HTTP embebido que expone endpoints para controlar la reproducción
/// de audio desde sistemas externos.
///
/// Útil en setups de totem/kiosk donde otro dispositivo o script puede
/// solicitar la reproducción de sonidos vía HTTP.
class HttpAudioEndpointService {
  HttpServer? _server;
  final int port;

  HttpAudioEndpointService({this.port = 8080});

  /// Inicia el servidor en [port]. Si [port] es 0, el sistema asigna uno
  /// disponible automáticamente.
  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      final actualPort = _server!.port;
      if (kDebugMode) {
        debugPrint(
            '[HttpAudioEndpoint] Servidor iniciado en http://0.0.0.0:$actualPort');
      }

      await for (final request in _server!) {
        _handleRequest(request);
      }
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint(
            '[HttpAudioEndpoint] No se pudo iniciar el servidor: $e');
      }
    }
  }

  void _handleRequest(HttpRequest request) {
    final response = request.response;

    // Headers CORS básicos para permitir llamadas desde cualquier origen.
    response.headers.add('Access-Control-Allow-Origin', '*');
    response.headers.add('Access-Control-Allow-Methods', 'GET, OPTIONS');
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type');
    response.headers.contentType = ContentType.json;

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      response.close();
      return;
    }

    if (request.method == 'GET' && request.uri.path == '/play-question') {
      AudioService.playQuestion();
      response.statusCode = HttpStatus.ok;
      response.write(jsonEncode({
        'success': true,
        'message': 'Reproduciendo audio: question_coffe',
      }));
    } else {
      response.statusCode = HttpStatus.notFound;
      response.write(jsonEncode({
        'success': false,
        'message': 'Endpoint no encontrado',
      }));
    }

    response.close();
  }

  /// Detiene el servidor.
  Future<void> stop() async {
    await _server?.close();
    _server = null;
    if (kDebugMode) {
      debugPrint('[HttpAudioEndpoint] Servidor detenido.');
    }
  }
}
