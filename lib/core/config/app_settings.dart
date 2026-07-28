import 'dart:async';

import 'package:flutter/foundation.dart';

import 'config_storage.dart';
import 'product_filter_config.dart';

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
  List<int> merchantIds = [];
  int productId = 0;
  bool enableImageCache = true;
  String baseUrlVpn = '';
  int portVpn = 0;

  /// Configuracion de visibilidad de merchants y productos.
  ProductFilterConfig filterConfig = ProductFilterConfig(
    filterMode: 'all',
  );

  /// Compatibilidad temporal: retorna el primer merchantId de la lista.
  /// @deprecated Usar merchantIds directamente cuando sea posible.
  int get merchantId => merchantIds.isNotEmpty ? merchantIds.first : 0;

  /// Nombre del cliente usado al crear órdenes.
  // static String customerName = 'Mesero-test-prod';
  static String customerName = 'Robot Mesero';

  bool get isConfigured =>
      baseUrl.isNotEmpty &&
      bearerToken.isNotEmpty &&
      merchantIds.isNotEmpty &&
      productId != 0;

  /// Carga la configuracion desde el disco o aplica fallback.
  Future<void> load() async {
    try {
      final saved = await ConfigStorage.read();
      if (saved != null) {
        baseUrl = saved['baseUrl'] as String? ?? _defaults.baseUrl;
        bearerToken = saved['bearerToken'] as String? ?? _defaults.bearerToken;

        // Cargar merchantIds (soporta tanto lista como valor único por compatibilidad)
        final savedMerchantIds = saved['merchantIds'];
        if (savedMerchantIds is List) {
          merchantIds =
              savedMerchantIds.map((e) => (e as num).toInt()).toList();
        } else if (savedMerchantIds is num) {
          // Compatibilidad con configuración antigua (un solo merchantId)
          merchantIds = [savedMerchantIds.toInt()];
        } else {
          merchantIds = _defaults.merchantIds;
        }

        productId =
            (saved['productId'] as num?)?.toInt() ?? _defaults.productId;
        baseUrlVpn = saved['baseUrlVpn'] as String? ?? _defaults.baseUrlVpn;
        portVpn = (saved['portVpn'] as num?)?.toInt() ?? _defaults.portVpn;

        // Cargar filtro de productos si existe
        if (saved['filterConfig'] is Map) {
          filterConfig = ProductFilterConfig.fromJson(
              saved['filterConfig'] as Map<String, dynamic>);
        }

        if (kDebugMode) {
          debugPrint(
              '[AppSettings] Configuracion cargada desde disco. Merchants: $merchantIds, filterMode: ${filterConfig.filterMode}');
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
    merchantIds = _defaults.merchantIds;
    productId = _defaults.productId;
    baseUrlVpn = _defaults.baseUrlVpn;
    portVpn = _defaults.portVpn;
    enableImageCache = true;
    // Whitelist: solo mostrar los productos con estos IDs
    filterConfig = ProductFilterConfig(
      // pinnedProducts: {489150, 489161},
      filterMode: 'all',
    );
    if (kDebugMode) {
      debugPrint(
          '[AppSettings] Usando configuracion por defecto (fallback). Merchants: $merchantIds');
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
  // static const List<int> merchantIds = [53];
  static const List<int> merchantIds = [53];
  static const int productId = 457969;
  // static const String baseUrlVpn = "10.13.13.17";
  // static const String baseUrlVpn = "192.168.21.71";
  static const String baseUrlVpn = "localhost";
  static const int portVpn = 5050;
}
