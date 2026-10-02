import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'merchant_config.dart';

/// Crea [MerchantConfig] desde la respuesta del endpoint
/// `GET /api/merchants/{id}`.
///
/// Determina el proveedor correcto basado en
/// `configuration.externalSystem`:
/// - `"patio_service"` → [ProductProviderType.legacy]
/// - cualquier otro    → [ProductProviderType.ecosystem]
///
/// Para ecosystem, extrae `companyExternalId`, `companyChannelExternalId`
/// y `merchantExternalId` de la respuesta.
class MerchantConfigFactory {
  MerchantConfigFactory._();

  /// Crea un [MerchantConfig] desde el JSON del endpoint
  /// `GET /api/merchants/{id}`.
  static MerchantConfig create(Map<String, dynamic> json) {
    final merchantId = json['id'] as int;
    final name = (json['name'] as String?) ?? '';
    final logo = json['urlLogo'] as String?;
    final billingType = _normalizeBillingType(json['billingType']);

    final config = json['configuration'] as Map<String, dynamic>?;
    final externalSystem =
        config?['externalSystem'] as String? ?? 'patio_service';

    final settings = AppSettings();

    if (externalSystem == 'patio_service') {
      debugPrint(
          '[MerchantConfigFactory] Merchant $merchantId → LEGACY (patio_service)');
      return MerchantConfig.legacy(
        merchantId: merchantId,
        baseUrl: settings.baseUrl,
        bearerToken: settings.bearerToken,
        merchantName: name,
        merchantLogo: logo,
        billingType: billingType,
      );
    }
    // merchant_panel → ecosystem
    debugPrint(
        '[MerchantConfigFactory] Merchant $merchantId → ECOSYSTEM (merchant_panel)');

    final companyId = int.tryParse(json['companyExternalId']?.toString() ?? '');
    final channelId =
        int.tryParse(json['companyChannelExternalId']?.toString() ?? '');
    final storeId = int.tryParse(json['merchantExternalId']?.toString() ?? '');

    debugPrint(
        '[MerchantConfigFactory] IDs: companyExternalId=${json['companyExternalId']}, '
        'companyChannelExternalId=${json['companyChannelExternalId']}, '
        'merchantExternalId=${json['merchantExternalId']}');
    if (companyId == null || channelId == null || storeId == null) {
      debugPrint('[MerchantConfigFactory] WARN: Missing ecosystem IDs. '
          'companyExternalId=${json['companyExternalId']}, '
          'companyChannelExternalId=${json['companyChannelExternalId']}, '
          'merchantExternalId=${json['merchantExternalId']}');
    }

    final ecosystemBaseUrl = settings.ecosystemBaseUrl.endsWith('/api')
        ? settings.ecosystemBaseUrl.substring(
            0,
            settings.ecosystemBaseUrl.length - '/api'.length,
          )
        : settings.ecosystemBaseUrl;

    return MerchantConfig.ecosystem(
      merchantId: merchantId,
      baseUrl: ecosystemBaseUrl,
      bearerToken: settings.ecosystemBearerToken,
      merchantName: name,
      merchantLogo: logo,
      billingType: billingType,
      companyId: companyId ?? 0,
      channelId: channelId ?? 0,
      storeId: storeId ?? 0,
    );
  }

  static String _normalizeBillingType(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized.isEmpty ? 'none' : normalized;
  }
}
