import 'dart:async';

import 'package:flutter/foundation.dart';

import 'config_storage.dart';

/// Configuracion de la app cargada en runtime.
///
/// Al iniciar, intenta leer valores previamente guardados en disco.
/// Si no existen, aplica los valores por defecto (fallback).
class AppSettings {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  String baseUrl = '';
  String bearerToken = '';
  int merchantId = 0;
  int productId = 0;
  bool enableImageCache = true;

  bool get isConfigured =>
      baseUrl.isNotEmpty &&
      bearerToken.isNotEmpty &&
      merchantId != 0 &&
      productId != 0;

  /// Carga la configuracion desde el disco o aplica fallback.
  Future<void> load() async {
    try {
      final saved = await ConfigStorage.read();
      if (saved != null) {
        baseUrl = saved['baseUrl'] as String? ?? _defaults.baseUrl;
        bearerToken = saved['bearerToken'] as String? ?? _defaults.bearerToken;
        merchantId = (saved['merchantId'] as num?)?.toInt() ?? _defaults.merchantId;
        productId = (saved['productId'] as num?)?.toInt() ?? _defaults.productId;
        if (kDebugMode) {
          debugPrint('[AppSettings] Configuracion cargada desde disco.');
        }
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppSettings] Error cargando desde disco: $e');
      }
    }

    // Fallback por defecto
    applyFallback();
  }

  /// Aplica los valores por defecto.
  void applyFallback() {
    baseUrl = _defaults.baseUrl;
    bearerToken = _defaults.bearerToken;
    merchantId = _defaults.merchantId;
    productId = _defaults.productId;
    if (kDebugMode) {
      debugPrint('[AppSettings] Usando configuracion por defecto (fallback).');
    }
  }
}

/// Valores por defecto cuando no hay config guardada.
abstract final class _defaults {
  // static const String baseUrl = 'https://api-totem.sandbox.nexuspatiotech.com/api';
  static const String baseUrl = 'https://api-totem.nexuspatiotech.com/api';
  static const String bearerToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJUT1RFTTAxNiIsImxpY2Vuc2VLZXkiOiJUT1RFTTAwMSIsInR5cGUiOiJ0b3RlbSIsImlhdCI6MTc4MjQxMDQ5MCwiZXhwIjoxODEzOTQ2NDkwfQ.M9fdig91KYqiGBTrrFMYfYjsRf5ZhmvICxT_q1yeDLs';
  // static const String bearerToken =
  //     'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJUT1RFTTAxNiIsImxpY2Vuc2VLZXkiOiJUT1RFTTAwMSIsInR5cGUiOiJ0b3RlbSIsImlhdCI6MTc4MTg3NzYwOCwiZXhwIjoxNzgyNDgyNDA4fQ.Xo3OUCmC0dxNM4MWBzltcYBBYzRHVQ3C98ZadFgI7Gc';
  // static const int merchantId = 53;
  static const int merchantId = 53;
  static const int productId = 457969;
}
