import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/domain/entities/merchant.dart';
import 'package:mini_app_qr/domain/entities/product.dart';
import 'package:mini_app_qr/presentation/bloc/home_state.dart';

void main() {
  const coffee = Product(
    id: 1,
    merchantId: 53,
    name: 'Cafe',
    description: '',
    price: 10,
    urlImage: '',
  );
  const tea = Product(
    id: 2,
    merchantId: 53,
    name: 'Te',
    description: '',
    price: 5,
    urlImage: '',
  );

  group('HomeState carrito', () {
    test('calcula productos, unidades y total usando las cantidades', () {
      final state = HomeState(
        products: const [coffee, tea],
        cartQuantities: {
          HomeState.cartKey(coffee): 2,
          HomeState.cartKey(tea): 3,
        },
      );

      expect(state.cartProducts, const [coffee, tea]);
      expect(state.cartTotalItems, 5);
      expect(state.cartTotal, 35);
    });

    test('distingue el mismo ID cuando pertenece a otro merchant', () {
      const otherMerchantCoffee = Product(
        id: 1,
        merchantId: 99,
        name: 'Cafe externo',
        description: '',
        price: 20,
        urlImage: '',
      );
      final state = HomeState(
        products: const [coffee, otherMerchantCoffee],
        cartQuantities: {HomeState.cartKey(coffee): 1},
      );

      expect(state.quantityFor(coffee), 1);
      expect(state.quantityFor(otherMerchantCoffee), 0);
    });
  });

  group('HomeState facturacion', () {
    test('resuelve la politica por merchantId', () {
      final state = HomeState(
        merchantsById: const {
          53: Merchant(
            id: 53,
            name: 'Sin factura',
            billingType: 'none',
          ),
          99: Merchant(
            id: 99,
            name: 'Con factura',
            billingType: 'merchant_system',
          ),
        },
      );

      expect(state.merchantUsesBilling(53), isFalse);
      expect(state.merchantUsesBilling(99), isTrue);
      expect(state.merchantUsesBilling(404), isFalse);
    });
  });
}
