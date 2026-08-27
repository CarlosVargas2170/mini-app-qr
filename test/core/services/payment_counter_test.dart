import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/core/services/payment_counter.dart';

void main() {
  late PaymentCounter counter;

  setUp(() {
    counter = PaymentCounter();
    counter.reset();
  });

  test('cuenta unidades de un producto sin convertirlas en varias ventas', () {
    counter.increment(
      amount: 30,
      productId: 1,
      productName: 'Cafe',
      merchantId: 53,
      cartItems: const [
        {'id': 1, 'name': 'Cafe', 'quantity': 3, 'price': 10.0},
      ],
    );

    final json = counter.toJson();
    final products = json['byProduct'] as List<dynamic>;

    expect(json['totalSales'], 1);
    expect(json['totalOrders'], 1);
    expect(json['totalUnits'], 3);
    expect(products.single['count'], 3);
    expect(products.single['quantity'], 3);
    expect(products.single['total'], 30);
  });

  test('resume por separado las cantidades de un carrito multiproducto', () {
    counter.increment(
      amount: 35,
      productId: 1,
      productName: 'Pedido (2 productos)',
      merchantId: 53,
      cartItems: const [
        {'id': 1, 'name': 'Cafe', 'quantity': 2, 'price': 10.0},
        {'id': 2, 'name': 'Te', 'quantity': 3, 'price': 5.0},
      ],
    );

    final json = counter.toJson();
    final products = json['byProduct'] as List<dynamic>;
    final recent = json['recent'] as List<dynamic>;

    expect(json['totalSales'], 1);
    expect(json['totalUnits'], 5);
    expect(products, hasLength(2));
    expect(products[0]['name'], 'Cafe');
    expect(products[0]['count'], 2);
    expect(products[1]['name'], 'Te');
    expect(products[1]['count'], 3);
    expect(recent.single['quantity'], 5);
    expect(recent.single['items'], hasLength(2));
  });

  test('mantiene compatible el flujo anterior de un solo producto', () {
    counter.increment(
      amount: 10,
      productId: 1,
      productName: 'Cafe',
      merchantId: 53,
    );

    final json = counter.toJson();
    final products = json['byProduct'] as List<dynamic>;

    expect(json['totalSales'], 1);
    expect(json['totalUnits'], 1);
    expect(products.single['count'], 1);
    expect(products.single['total'], 10);
  });
}
