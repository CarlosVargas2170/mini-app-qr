import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/domain/entities/merchant.dart';

void main() {
  group('Merchant.usesBilling', () {
    test('es falso para none sin importar espacios o mayusculas', () {
      const merchant = Merchant(
        id: 53,
        name: 'Merchant',
        billingType: ' NONE ',
      );

      expect(merchant.usesBilling, isFalse);
    });

    test('es falso cuando billingType esta vacio', () {
      const merchant = Merchant(
        id: 53,
        name: 'Merchant',
        billingType: '  ',
      );

      expect(merchant.usesBilling, isFalse);
    });

    test('es verdadero para un sistema de facturacion configurado', () {
      const merchant = Merchant(
        id: 53,
        name: 'Merchant',
        billingType: 'merchant_system',
      );

      expect(merchant.usesBilling, isTrue);
    });
  });
}
