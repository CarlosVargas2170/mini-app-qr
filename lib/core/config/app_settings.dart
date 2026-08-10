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
  List<int> merchantIds = [];
  int productId = 0;
  bool enableImageCache = true;
  String baseUrlVpn = '';
  int portVpn = 0;

  /// Configuracion de visibilidad de merchants y productos.
  ProductFilterConfig filterConfig = ProductFilterConfig(
    filterMode: 'all',
  );

  /// Intervalo en segundos del polling automático de productos.
  /// 0 = deshabilitado. Por defecto: 30 segundos.
  int productPollingIntervalSeconds = 30;

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
    productPollingIntervalSeconds =
        int.tryParse(dotenv.env['PRODUCT_POLLING_INTERVAL_SECONDS'] ?? '') ??
            _defaults.productPollingIntervalSeconds;
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
  static const int productPollingIntervalSeconds = 30;
}
