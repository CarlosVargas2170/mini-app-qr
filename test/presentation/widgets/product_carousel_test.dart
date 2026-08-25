import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/presentation/widgets/product_carousel.dart';

void main() {
  group('buildVisibleIndicatorIndices', () {
    test('returns every indicator when there are seven or fewer products', () {
      expect(
        buildVisibleIndicatorIndices(count: 5, current: 2),
        [0, 1, 2, 3, 4],
      );
    });

    test('limits indicators and keeps the current product centered', () {
      expect(
        buildVisibleIndicatorIndices(count: 20, current: 10),
        [7, 8, 9, 10, 11, 12, 13],
      );
    });

    test('anchors the indicator window at the beginning', () {
      expect(
        buildVisibleIndicatorIndices(count: 20, current: 1),
        [0, 1, 2, 3, 4, 5, 6],
      );
    });

    test('anchors the indicator window at the end', () {
      expect(
        buildVisibleIndicatorIndices(count: 20, current: 18),
        [13, 14, 15, 16, 17, 18, 19],
      );
    });

    test('returns no indicators when there are no products', () {
      expect(buildVisibleIndicatorIndices(count: 0, current: 0), isEmpty);
    });
  });
}
