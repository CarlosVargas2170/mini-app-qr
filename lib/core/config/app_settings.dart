import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  int get merchantId => merchantIds.isNotEmpty ? merchantIds.first : 0;
  static String customerName = dotenv.env['NAME_MESERO'] ?? 'Robot Mesero';
  static int qrExpirationMinutes = int.tryParse(dotenv.env['QR_EXPIRATION_MINUTES'] ?? '') ?? 3;

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
        baseUrl = dotenv.env['BASE_URL'] ?? _defaults.baseUrl;
        bearerToken = dotenv.env['BEARER_TOKEN'] ?? _defaults.bearerToken;
        // baseUrl = saved['baseUrl'] as String? ?? _defaults.baseUrl;
        // bearerToken = saved['bearerToken'] as String? ?? _defaults.bearerToken;

        // Cargar merchantIds (soporta tanto lista como valor único por compatibilidad)
        // final savedMerchantIds = saved['merchantIds'];
        // if (savedMerchantIds is List) {
        //   merchantIds =
        //       savedMerchantIds.map((e) => (e as num).toInt()).toList();
        // } else if (savedMerchantIds is num) {
        //   // Compatibilidad con configuración antigua (un solo merchantId)
        //   merchantIds = [savedMerchantIds.toInt()];
        // } else {
        //   merchantIds = _defaults.merchantIds;
        // }

        merchantIds = dotenv.env['MERCHANT_IDS']
            ?.split(',')
            .map((e) => int.parse(e.trim()))
            .toList() ??
        _defaults.merchantIds;

        productId = int.tryParse(dotenv.env['PRODUCT_ID'] ?? '') ?? _defaults.productId;
        // baseUrlVpn = saved['baseUrlVpn'] as String? ?? _defaults.baseUrlVpn;
        baseUrlVpn = dotenv.env['BASE_URL_VPN'] ?? _defaults.baseUrlVpn;
        portVpn = int.tryParse(dotenv.env['PORT_VPN'] ?? '') ?? _defaults.portVpn;

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

    applyFallback();
  }

  void applyFallback() {
    baseUrl = dotenv.env['BASE_URL'] ?? _defaults.baseUrl;
    bearerToken = dotenv.env['BEARER_TOKEN'] ?? _defaults.bearerToken;
    merchantIds = dotenv.env['MERCHANT_IDS']
            ?.split(',')
            .map((e) => int.parse(e.trim()))
            .toList() ??
        _defaults.merchantIds;
    productId =
        int.tryParse(dotenv.env['PRODUCT_ID'] ?? '') ?? _defaults.productId;
    baseUrlVpn = dotenv.env['BASE_URL_VPN'] ?? _defaults.baseUrlVpn;
    portVpn = int.tryParse(dotenv.env['PORT_VPN'] ?? '') ?? _defaults.portVpn;
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
  static const String baseUrl = 'https://api-totem.nexuspatiotech.com/api';
  static const String bearerToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOjIwLCJlbWFpbCI6ImhlY3ZhbkBnbWFpbC5jb20iLCJyb2xlIjoic3VwZXItYWRtaW4iLCJ0eXBlIjoidXNlciIsImlhdCI6MTc4NTUzMDA2NCwiZXhwIjoxODE3MDY2MDY0fQ.pO_jWIuOz_ck5v14RjpRi822ORmegCpx_IdG0kt-ZUI';
  static const List<int> merchantIds = [53];
  static const int productId = 457969;
  static const String baseUrlVpn = "100.99.244.72";
  static const int portVpn = 5050;
}
