import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/core/config/app_settings.dart';
import 'package:mini_app_qr/core/services/app_server.dart';

void main() {
  group('buildPublicConfigData', () {
    test('excluye credenciales de la respuesta publica', () {
      final settings = AppSettings()
        ..baseUrl = 'https://api.example.com'
        ..bearerToken = 'secret-token'
        ..ecosystemBearerToken = 'ecosystem-secret';

      final data = buildPublicConfigData(settings);

      expect(data, isNot(contains('bearerToken')));
      expect(data, isNot(contains('ecosystemBearerToken')));
      expect(data['baseUrl'], 'https://api.example.com');
    });
  });
}
