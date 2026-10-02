import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/data/models/place_order_request.dart';

void main() {
  group('PlaceOrderRequestDto', () {
    test('envia varios productos con cantidades y total correctos', () {
      final request = PlaceOrderRequestDto(
        merchantId: 53,
        customerName: 'Robot',
        paymentReferenceOverride: 'TEST-ORDER',
        cartItems: const [
          {'id': 1, 'name': 'Cafe', 'quantity': 2, 'price': 10.0},
          {'id': 2, 'name': 'Te', 'quantity': 3, 'price': 5.0},
        ],
        menuData: const {
          'merchantName': 'Cafeteria',
          'categories': [
            {
              'products': [
                {'id': 1, 'name': 'Cafe', 'price': 10.0},
                {'id': 2, 'name': 'Te', 'price': 5.0},
              ],
            },
          ],
        },
      );

      final json = request.toJson();
      final cart = json['cart'] as Map<String, dynamic>;
      final items = cart['items'] as List<dynamic>;

      expect(items, hasLength(2));
      expect(items[0]['quantity'], 2);
      expect(items[0]['totalPrice'], 20);
      expect(items[1]['quantity'], 3);
      expect(items[1]['totalPrice'], 15);
      expect(cart['subtotal'], 35);
      expect(cart['total'], 35);
      expect(json['paymentReference'], 'TEST-ORDER');
    });

    test('agrupa por ID las entradas repetidas del mismo producto', () {
      final request = PlaceOrderRequestDto(
        merchantId: 53,
        customerName: 'Robot',
        cartItems: const [
          {'id': 1, 'name': 'Cafe', 'quantity': 2, 'price': 10.0},
          {'id': 1, 'name': 'Cafe nuevo', 'quantity': 3, 'price': 10.0},
        ],
      );

      final cart = request.toJson()['cart'] as Map<String, dynamic>;
      final items = cart['items'] as List<dynamic>;

      expect(items, hasLength(1));
      expect(items.single['quantity'], 5);
      expect(items.single['totalPrice'], 50);
    });

    test('incluye y recorta los datos de facturacion', () {
      final request = PlaceOrderRequestDto(
        merchantId: 53,
        customerName: 'Robot',
        nit: ' 1234567890123 ',
        businessName: ' Empresa SRL ',
        cartItems: const [],
      );

      final json = request.toJson();

      expect(json['nit'], '1234567890123');
      expect(json['businessName'], 'Empresa SRL');
    });

    test('omite los datos de facturacion vacios', () {
      final request = PlaceOrderRequestDto(
        merchantId: 53,
        customerName: 'Robot',
        nit: '   ',
        businessName: '',
        cartItems: const [],
      );

      final json = request.toJson();

      expect(json, isNot(contains('nit')));
      expect(json, isNot(contains('businessName')));
    });
  });
}
