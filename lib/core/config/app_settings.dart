import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  String ecosystemBaseUrl = '';
  String ecosystemBearerToken = '';
  List<int> merchantIds = [];
  int productId = 0;
  bool enableImageCache = true;
  String baseUrlVpn = '';
  int portVpn = 0;

  /// Configuracion de visibilidad de merchants y productos.
  ProductFilterConfig filterConfig = ProductFilterConfig(
    filterMode: 'all',
  );

  /// Tiempo mínimo entre polls de productos (en segundos).
  /// Si el último poll fue hace menos de este tiempo, se omite.
  /// Default: 60 segundos.
  int productPollingStaleSeconds = 60;

  /// Cantidad maxima permitida de un mismo producto en el carrito.
  int maxCartItemQuantity = 10;

  /// Tiempo sin interaccion antes de iniciar una nueva sesion.
  int customerSessionTimeoutSeconds = 60;

  int get merchantId => merchantIds.isNotEmpty ? merchantIds.first : 0;
  static String customerName = dotenv.env['NAME_MESERO'] ?? 'Robot Mesero';
  static int qrExpirationMinutes =
      int.tryParse(dotenv.env['QR_EXPIRATION_MINUTES'] ?? '') ?? 3;

  bool get isConfigured =>
      baseUrl.isNotEmpty &&
      bearerToken.isNotEmpty &&
      merchantIds.isNotEmpty &&
      productId != 0;

  /// Carga la configuracion desde el archivo .env.
  /// El filterConfig siempre arranca limpio (filterMode: 'all').
  Future<void> load() async {
    applyFallback();
  }

  void applyFallback() {
    baseUrl = dotenv.env['BASE_URL'] ?? _Defaults.baseUrl;
    bearerToken = dotenv.env['BEARER_TOKEN'] ?? _Defaults.bearerToken;
    ecosystemBaseUrl =
        dotenv.env['ECOSYSTEM_BASE_URL'] ?? _Defaults.ecosystemBaseUrl;
    ecosystemBearerToken =
        dotenv.env['ECOSYSTEM_BEARER_TOKEN'] ?? _Defaults.ecosystemBearerToken;
    merchantIds = dotenv.env['MERCHANT_IDS']
            ?.split(',')
            .map((e) => int.parse(e.trim()))
            .toList() ??
        _Defaults.merchantIds;
    productId =
        int.tryParse(dotenv.env['PRODUCT_ID'] ?? '') ?? _Defaults.productId;
    baseUrlVpn = dotenv.env['BASE_URL_VPN'] ?? _Defaults.baseUrlVpn;
    portVpn = int.tryParse(dotenv.env['PORT_VPN'] ?? '') ?? _Defaults.portVpn;
    productPollingStaleSeconds =
        int.tryParse(dotenv.env['PRODUCT_POLLING_STALE_SECONDS'] ?? '') ??
            _Defaults.productPollingStaleSeconds;
    final configuredMaxCartQuantity =
        int.tryParse(dotenv.env['MAX_CART_ITEM_QUANTITY'] ?? '');
    maxCartItemQuantity = configuredMaxCartQuantity != null &&
            configuredMaxCartQuantity > 0
        ? configuredMaxCartQuantity
        : _Defaults.maxCartItemQuantity;
    final configuredSessionTimeout =
        int.tryParse(dotenv.env['CUSTOMER_SESSION_TIMEOUT_SECONDS'] ?? '');
    customerSessionTimeoutSeconds = configuredSessionTimeout != null &&
            configuredSessionTimeout > 0
        ? configuredSessionTimeout
        : _Defaults.customerSessionTimeoutSeconds;
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
abstract final class _Defaults {
  static const String baseUrl = 'https://api-totem.nexuspatiotech.com/api';
  static const String bearerToken = '';
  static const String ecosystemBaseUrl =
      'https://api-merchant.nexuspatiotech.com';
  static const String ecosystemBearerToken = '';
  static const List<int> merchantIds = [53];
  static const int productId = 457969;
  static const String baseUrlVpn = "100.99.244.72";
  static const int portVpn = 5050;
  static const int productPollingStaleSeconds = 60;
  static const int maxCartItemQuantity = 10;
  static const int customerSessionTimeoutSeconds = 60;
}
