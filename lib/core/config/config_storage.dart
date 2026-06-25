import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Persistencia local de la configuracion de la app.
///
/// Guarda y lee un archivo JSON (`app_settings.json`).
/// Intenta primero en el directorio del ejecutable, y si falla por permisos,
/// usa el directorio de trabajo actual como fallback.
class ConfigStorage {
  static const String _fileName = 'app_settings.json';

  /// Rutas candidatas donde intentar escribir (en orden de prioridad).
  static List<String> get _candidatePaths {
    return [
      // 1. Directorio del ejecutable (preferido)
      '${File(Platform.resolvedExecutable).parent.path}/$_fileName',
      // 2. Directorio de trabajo actual (fallback para Linux/snap/docker)
      '${Directory.current.path}/$_fileName',
    ];
  }

  /// Lee la configuracion guardada. Devuelve `null` si no existe.
  static Future<Map<String, dynamic>?> read() async {
    for (final path in _candidatePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          if (kDebugMode) debugPrint('[ConfigStorage] Config leida desde: $path');
          return jsonDecode(content) as Map<String, dynamic>;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[ConfigStorage] Error leyendo $path: $e');
      }
    }
    if (kDebugMode) debugPrint('[ConfigStorage] No se encontro config en ninguna ruta candidata.');
    return null;
  }

  /// Guarda la configuracion en disco.
  /// Intenta cada ruta candidata hasta que una funcione.
  static Future<void> write(Map<String, dynamic> config) async {
    final errors = <String>[];

    for (final path in _candidatePaths) {
      try {
        final file = File(path);
        await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(config),
          flush: true,
        );
        if (kDebugMode) debugPrint('[ConfigStorage] Config guardada en: $path');
        return; // Exito
      } catch (e) {
        errors.add('$path -> $e');
        if (kDebugMode) debugPrint('[ConfigStorage] Fallo escribir en $path: $e');
      }
    }

    // Si llegamos aqui, ninguna ruta funciono
    final msg = 'No se pudo guardar la configuracion en ninguna ruta:\n${errors.join("\n")}';
    if (kDebugMode) debugPrint('[ConfigStorage] ERROR: $msg');
    throw Exception(msg);
  }
}
