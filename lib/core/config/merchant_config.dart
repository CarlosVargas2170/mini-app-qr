/// Proveedor de productos de un merchant.
enum ProductProviderType {
  /// Endpoint legacy: /v1/merchants/{id}/products-categories
  legacy,

  /// Endpoint ecosystem: /ecosystem/companies/{id}/channels/{id}/menu
  ecosystem,
}

/// Configuración de conexión para cargar los productos de un merchant.
///
/// Contiene la URL base, token y parámetros necesarios para que
/// [ProductDataSourceFactory] cree el DataSource correcto.
class MerchantConfig {
  final int merchantId;
  final ProductProviderType provider;
  final String baseUrl;
  final String bearerToken;
  final String merchantName;
  final String? merchantLogo;

  // ─── Ecosystem only ───
  final int? companyId;
  final int? channelId;
  final int? storeId;

  bool get isLegacy => provider == ProductProviderType.legacy;
  bool get isEcosystem => provider == ProductProviderType.ecosystem;

  MerchantConfig.legacy({
    required this.merchantId,
    required this.baseUrl,
    required this.bearerToken,
    required this.merchantName,
    this.merchantLogo,
  })  : provider = ProductProviderType.legacy,
        companyId = null,
        channelId = null,
        storeId = null;

  MerchantConfig.ecosystem({
    required this.merchantId,
    required this.baseUrl,
    required this.bearerToken,
    required this.merchantName,
    this.merchantLogo,
    required this.companyId,
    required this.channelId,
    required this.storeId,
  }) : provider = ProductProviderType.ecosystem;
}
