import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/core/config/merchant_config_factory.dart';

void main() {
  group('MerchantConfigFactory billingType', () {
    test('lee el billingType superior y no el de configuration', () {
      final config = MerchantConfigFactory.create({
        'id': 53,
        'name': 'Cofi Mega Center',
        'billingType': 'none',
        'merchantExternalId': '72',
        'companyExternalId': '31',
        'companyChannelExternalId': '162',
        'configuration': {
          'externalSystem': 'merchant_panel',
          'billingType': 'merchant_system',
        },
      });

      expect(config.billingType, 'none');
    });

    test('normaliza un valor configurado', () {
      final config = MerchantConfigFactory.create({
        'id': 53,
        'name': 'Merchant',
        'billingType': ' MERCHANT_SYSTEM ',
        'configuration': {'externalSystem': 'patio_service'},
      });

      expect(config.billingType, 'merchant_system');
    });

    test('usa none cuando el campo no esta presente', () {
      final config = MerchantConfigFactory.create({
        'id': 53,
        'name': 'Merchant',
        'configuration': {'externalSystem': 'patio_service'},
      });

      expect(config.billingType, 'none');
    });
  });
}
