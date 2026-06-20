/// Configuración centralizada de la app.
///
/// Valores del backend sandbox para merchant 53 y producto 457969.
abstract final class AppConfig {
  static const String baseUrl = 'https://api-totem.sandbox.nexuspatiotech.com/api';

  static const String bearerToken =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJUT1RFTTAxNiIsImxpY2Vuc2VLZXkiOiJUT1RFTTAwMSIsInR5cGUiOiJ0b3RlbSIsImlhdCI6MTc4MTg3NzYwOCwiZXhwIjoxNzgyNDgyNDA4fQ.Xo3OUCmC0dxNM4MWBzltcYBBYzRHVQ3C98ZadFgI7Gc';

// producto seleccionado 
  static const int merchantId = 53;
  static const int productId  = 457969;
}
