import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Persistencia local de la configuracion de la app.
///
/// Guarda y lee un archivo JSON (`app_settings.json`) en el mismo
/// directorio donde se encuentra el ejecutable.
class ConfigStorage {
  static const String _fileName = 'app_settings.json';

  /// Ruta absoluta del archivo de configuracion.
  static Future<String> get _filePath async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir/$_fileName';
  }

  /// Lee la configuracion guardada. Devuelve `null` si no existe.
  static Future<Map<String, dynamic>?> read() async {
    try {
      final path = await _filePath;
      final file = File(path);
      if (!await file.exists()) return null;

      final content = await file.readAsString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      if (kDebugMode) debugPrint('[ConfigStorage] Error leyendo config: $e');
      return null;
    }
  }

  /// Guarda la configuracion en disco.
  static Future<void> write(Map<String, dynamic> config) async {
    try {
      final path = await _filePath;
      final file = File(path);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(config),
        flush: true,
      );
      if (kDebugMode) debugPrint('[ConfigStorage] Config guardada en $path');
    } catch (e) {
      if (kDebugMode) debugPrint('[ConfigStorage] Error guardando config: $e');
      rethrow;
    }
  }
}
