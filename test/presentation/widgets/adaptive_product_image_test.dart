import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/presentation/widgets/adaptive_product_image.dart';

void main() {
  group('shouldContainProductImage', () {
    const squareContainer = Size(1000, 1000);

    test('keeps cover for square and nearly-square images', () {
      expect(
        shouldContainProductImage(
          imageSize: const Size(1000, 1000),
          containerSize: squareContainer,
        ),
        isFalse,
      );
      expect(
        shouldContainProductImage(
          imageSize: const Size(1200, 1000),
          containerSize: squareContainer,
        ),
        isFalse,
      );
    });

    test('uses contain for narrow portrait images', () {
      expect(
        shouldContainProductImage(
          imageSize: const Size(500, 1600),
          containerSize: squareContainer,
        ),
        isTrue,
      );
    });

    test('uses contain for extremely wide images', () {
      expect(
        shouldContainProductImage(
          imageSize: const Size(2400, 700),
          containerSize: squareContainer,
        ),
        isTrue,
      );
    });
  });
}
