import 'package:flutter_test/flutter_test.dart';
import 'package:mini_app_qr/data/mappers/topping_mapper.dart';
import 'package:mini_app_qr/data/models/ecosystem/topping_group_dto.dart';
import 'package:mini_app_qr/domain/entities/topping.dart';

void main() {
  group('mapLegacyToppings (proveedor patio_service)', () {
    test('mapea grupos con el type ya resuelto por el backend', () {
      final toppings = mapLegacyToppings([
        {
          'id': 325999,
          'name': 'TOPPING',
          'priority': 1,
          'maxLimit': 0,
          'minLimit': 0,
          'type': 'increment',
          'subToppings': [
            {
              'id': 1894774,
              'name': 'Dulce de leche',
              'priority': 1,
              'price': 2
            },
          ],
        },
      ]);

      expect(toppings, isNotNull);
      expect(toppings!.single.type, ToppingType.increment);
      expect(toppings.single.subToppings.single.name, 'Dulce de leche');
      expect(toppings.single.subToppings.single.price, 2.0);
    });

    test('devuelve null cuando la lista es null o vacia', () {
      expect(mapLegacyToppings(null), isNull);
      expect(mapLegacyToppings([]), isNull);
    });

    test('descarta un grupo que se queda sin sub-toppings', () {
      final toppings = mapLegacyToppings([
        {
          'id': 1,
          'name': 'Vacio',
          'minLimit': 0,
          'maxLimit': 0,
          'type': 'checkbox',
          'subToppings': [],
        },
      ]);

      expect(toppings, isNull);
    });

    test('un type desconocido cae a checkbox en vez de fallar', () {
      final toppings = mapLegacyToppings([
        {
          'id': 1,
          'name': 'Raro',
          'minLimit': 0,
          'maxLimit': 0,
          'type': 'algo-inesperado',
          'subToppings': [
            {'id': 1, 'name': 'Opcion', 'price': 0},
          ],
        },
      ]);

      expect(toppings!.single.type, ToppingType.checkbox);
    });
  });

  group('ToppingGroupDto.toTopping (proveedor ecosystem)', () {
    test('infiere increment cuando el groupType es extra', () {
      final group = ToppingGroupDto.fromJson({
        'idToppingGroup': 5,
        'nameGroup': 'Extras',
        'type': 'extra',
        'minRequired': 0,
        'maxAllowed': 3,
        'isHidden': false,
        'toppings': [
          {
            'idTopping': 50,
            'nameTopping': 'Queso',
            'price': 4.0,
            'isHidden': false
          },
        ],
      });

      expect(group.toTopping()!.type, ToppingType.increment);
    });

    test('infiere radio cuando maxAllowed es 1', () {
      final group = ToppingGroupDto.fromJson({
        'idToppingGroup': 6,
        'nameGroup': 'Tamano',
        'type': 'generico',
        'minRequired': 1,
        'maxAllowed': 1,
        'isHidden': false,
        'toppings': [
          {
            'idTopping': 60,
            'nameTopping': 'Grande',
            'price': 0.0,
            'isHidden': false
          },
        ],
      });

      expect(group.toTopping()!.type, ToppingType.radio);
    });

    test('infiere checkbox cuando maxAllowed es mayor a 1', () {
      final group = ToppingGroupDto.fromJson({
        'idToppingGroup': 7,
        'nameGroup': 'Salsas',
        'type': 'generico',
        'minRequired': 0,
        'maxAllowed': 2,
        'isHidden': false,
        'toppings': [
          {
            'idTopping': 70,
            'nameTopping': 'BBQ',
            'price': 0.0,
            'isHidden': false
          },
        ],
      });

      expect(group.toTopping()!.type, ToppingType.checkbox);
    });

    test('un grupo oculto no se muestra', () {
      final group = ToppingGroupDto.fromJson({
        'idToppingGroup': 8,
        'nameGroup': 'Oculto',
        'type': 'generico',
        'minRequired': 0,
        'maxAllowed': 1,
        'isHidden': true,
        'toppings': [
          {
            'idTopping': 80,
            'nameTopping': 'X',
            'price': 0.0,
            'isHidden': false
          },
        ],
      });

      expect(group.toTopping(), isNull);
    });

    test(
        'filtra sub-toppings ocultos y descarta el grupo si no queda ninguno visible',
        () {
      final group = ToppingGroupDto.fromJson({
        'idToppingGroup': 9,
        'nameGroup': 'Todo oculto',
        'type': 'generico',
        'minRequired': 0,
        'maxAllowed': 2,
        'isHidden': false,
        'toppings': [
          {'idTopping': 90, 'nameTopping': 'X', 'price': 0.0, 'isHidden': true},
        ],
      });

      expect(group.toTopping(), isNull);
    });
  });
}
