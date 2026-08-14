import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/domain/entities/product.dart';
import 'package:mini_app_qr/presentation/widgets/floating_cart.dart';

void main() {
  const product = Product(
    id: 1,
    merchantId: 53,
    name: 'Cafe',
    description: 'Cafe de prueba',
    price: 10,
    urlImage: '',
  );

  testWidgets('disminuye una unidad y mantiene abierto el carrito',
      (tester) async {
    await tester.pumpWidget(
      const _FloatingCartHarness(product: product, initialQuantity: 2),
    );

    await tester.tap(find.byKey(const ValueKey('cart-button')));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('cart-panel')), findsOneWidget);
    expect(find.textContaining('Cantidad: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al disminuir la ultima unidad vacia y cierra el carrito',
      (tester) async {
    await tester.pumpWidget(
      const _FloatingCartHarness(product: product, initialQuantity: 1),
    );

    await tester.tap(find.byKey(const ValueKey('cart-button')));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();

    expect(find.byKey(const ValueKey('cart-panel')), findsNothing);
    final cartButton = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(cartButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'disminuye cualquiera de varios productos y permite reabrir el carrito',
      (tester) async {
    const tea = Product(
      id: 2,
      merchantId: 53,
      name: 'Te',
      description: 'Te de prueba',
      price: 5,
      urlImage: '',
    );
    await tester.pumpWidget(
      const _MultiProductCartHarness(products: [product, tea]),
    );

    await tester.tap(find.byKey(const ValueKey('cart-button')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('cart-decrement-53-1')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('cart-panel')), findsOneWidget);
    expect(find.textContaining('Cantidad: 1'), findsOneWidget);
    expect(find.textContaining('Cantidad: 2'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('cart-button')));
    await tester.pump();

    expect(find.byKey(const ValueKey('cart-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FloatingCartHarness extends StatefulWidget {
  final Product product;
  final int initialQuantity;

  const _FloatingCartHarness({
    required this.product,
    required this.initialQuantity,
  });

  @override
  State<_FloatingCartHarness> createState() => _FloatingCartHarnessState();
}

class _FloatingCartHarnessState extends State<_FloatingCartHarness> {
  late int quantity = widget.initialQuantity;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: FloatingCart(
            products: quantity > 0 ? [widget.product] : const [],
            quantityFor: (_) => quantity,
            totalItems: quantity,
            totalAmount: widget.product.price * quantity,
            maxItemQuantity: 10,
            onIncrement: (_) => setState(() => quantity++),
            onDecrement: (_) => setState(() => quantity--),
            onRemove: (_) => setState(() => quantity = 0),
            onClear: () => setState(() => quantity = 0),
            onInteraction: () {},
          ),
        ),
      ),
    );
  }
}

class _MultiProductCartHarness extends StatefulWidget {
  final List<Product> products;

  const _MultiProductCartHarness({required this.products});

  @override
  State<_MultiProductCartHarness> createState() =>
      _MultiProductCartHarnessState();
}

class _MultiProductCartHarnessState extends State<_MultiProductCartHarness> {
  late final Map<int, int> quantities = {
    for (final product in widget.products) product.id: 2,
  };

  int quantityFor(Product product) => quantities[product.id] ?? 0;

  @override
  Widget build(BuildContext context) {
    final cartProducts = widget.products
        .where((product) => quantityFor(product) > 0)
        .toList();
    final totalItems = quantities.values.fold(0, (sum, value) => sum + value);
    final totalAmount = cartProducts.fold<double>(
      0,
      (sum, product) => sum + product.price * quantityFor(product),
    );

    return MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomRight,
          child: FloatingCart(
            products: cartProducts,
            quantityFor: quantityFor,
            totalItems: totalItems,
            totalAmount: totalAmount,
            maxItemQuantity: 10,
            onIncrement: (product) => setState(
              () => quantities[product.id] = quantityFor(product) + 1,
            ),
            onDecrement: (product) => setState(() {
              final nextQuantity = quantityFor(product) - 1;
              if (nextQuantity <= 0) {
                quantities.remove(product.id);
              } else {
                quantities[product.id] = nextQuantity;
              }
            }),
            onRemove: (product) => setState(
              () => quantities.remove(product.id),
            ),
            onClear: () => setState(quantities.clear),
            onInteraction: () {},
          ),
        ),
      ),
    );
  }
}
