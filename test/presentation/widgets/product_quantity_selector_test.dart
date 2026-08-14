import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/presentation/widgets/product_quantity_selector.dart';

void main() {
  testWidgets('deshabilita disminuir cuando la cantidad es cero',
      (tester) async {
    var decrements = 0;
    var increments = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductQuantitySelector(
            quantity: 0,
            maxQuantity: 10,
            onDecrement: () => decrements++,
            onIncrement: () => increments++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.add));

    expect(decrements, 0);
    expect(increments, 1);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('deshabilita aumentar al alcanzar la cantidad maxima',
      (tester) async {
    var increments = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductQuantitySelector(
            quantity: 10,
            maxQuantity: 10,
            onDecrement: () {},
            onIncrement: () => increments++,
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));

    expect(increments, 0);
    expect(find.text('10'), findsOneWidget);
  });
}
